from airflow import DAG
from operators.common_pipeline import CommonDag


SPORTS_CENTER_URL = "https://data.taipei/api/dataset/80be7612-593f-4795-9935-a10ce0f7b75b/resource/e7c46724-3517-4ce5-844f-5a4404897b7d/download"
REALTIME_URL = "https://booking-tpsc.sporetrofit.com/Home/loadLocationPeopleNum"
NTPC_CENTER_URL = "https://www.t-sports.ntpc.gov.tw/home.jsp?id=a6af86d2ea26b816&parentpath=null"
NTPC_BASE_URL = "https://www.t-sports.ntpc.gov.tw/"
SPORTABLE_VENUES_URL = "https://api.sportable.tw/api/v2/search/venues"
SPORTABLE_PEOPLE_URL = "https://api.sportable.tw/api/v2/statistics/people"


def _transfer(**kwargs):
    import html
    import io
    import re
    from urllib.parse import urljoin

    import pandas as pd
    import requests
    from sqlalchemy import create_engine
    from utils.get_time import get_tpe_now_time_str
    from utils.load_stage import (
        save_geodataframe_to_postgresql,
        update_lasttime_in_data_to_dataset_info,
    )
    from utils.transform_geometry import add_point_wkbgeometry_column_to_df

    ready_data_db_uri = kwargs.get("ready_data_db_uri")
    proxies = kwargs.get("proxies")
    dag_infos = kwargs.get("dag_infos")
    dag_id = dag_infos.get("dag_id")
    load_behavior = dag_infos.get("load_behavior")
    default_table = dag_infos.get("ready_data_default_table")
    history_table = dag_infos.get("ready_data_history_table")

    def normalize_center_name(value):
        if pd.isna(value):
            return None
        name = str(value).strip()
        name = re.sub(r"^新北市政府體育局", "", name).strip()
        name = name.replace("臺北市", "").replace("台北市", "").replace("新北市", "")
        name = name.replace("國民運動中心", "").replace("運動中心", "")
        return re.sub(r"\s+", "", name)

    def parse_capacity_rate(count, capacity):
        if pd.isna(count) or pd.isna(capacity) or capacity == 0:
            return pd.NA
        return count / capacity

    def request_ntpc(session, method, url, **request_kwargs):
        try:
            return session.request(method, url, **request_kwargs)
        except requests.exceptions.SSLError:
            return session.request(method, url, verify=False, **request_kwargs)

    def extract_text(fragment):
        text = html.unescape(re.sub(r"<[^>]+>", " ", fragment))
        return re.sub(r"\s+", " ", text).strip()

    def parse_ntpc_list(text):
        links = []
        seen = set()
        pattern = r'href=["\']([^"\']*dataserno=[^"\']+)["\'][^>]*>(.*?)</a>'
        for match in re.finditer(pattern, text, flags=re.IGNORECASE | re.DOTALL):
            href = html.unescape(match.group(1))
            title = extract_text(match.group(2))
            if not href or href in seen:
                continue
            seen.add(href)
            links.append({"detail_url": urljoin(NTPC_BASE_URL, href), "list_title": title})
        return links

    def parse_ntpc_detail(text, detail_url, list_title):
        text = html.unescape(text)
        title = list_title.split("/")[-1].strip() if list_title else None
        title = re.sub(r"^新北市政府體育局\s*", "", title) if title else None
        title_match = re.search(r"<h[12][^>]*>(.*?)</h[12]>", text, flags=re.DOTALL)
        if title_match:
            parsed_title = extract_text(title_match.group(1))
            if parsed_title:
                title = re.sub(r"^新北市政府體育局\s*", "", parsed_title)

        address = None
        address_match = re.search(r"位置</div>\s*<div[^>]*>(.*?)(?:<br|<iframe|</div>)", text, flags=re.DOTALL)
        if address_match:
            address = extract_text(address_match.group(1))
        if not address:
            address_match = re.search(r"([0-9]{3}新北市[^<\n\r]+)", text)
            address = extract_text(address_match.group(1)) if address_match else None

        phone = None
        phone_match = re.search(r"(?:電話|聯絡電話)[：:]\s*([^<\n\r]+)", text)
        if phone_match:
            phone = extract_text(phone_match.group(1))

        website = None
        website_match = re.search(
            r'href=["\'](https?://[^"\']+)["\'][^>]*>(?:[^<]*官方網站|[^<]*國民運動中心[^<]*)',
            text,
            flags=re.IGNORECASE,
        )
        if website_match:
            website = website_match.group(1)

        lng = lat = None
        map_match = re.search(r"!2d([0-9.]+)!3d([0-9.]+)", text)
        if map_match:
            lng = float(map_match.group(1))
            lat = float(map_match.group(2))

        return {
            "name": title,
            "postal_code": address[:3] if address and re.match(r"^\d{3}", address) else None,
            "address": address,
            "phone": phone,
            "website": website,
            "lng": lng,
            "lat": lat,
            "source_url": detail_url,
            "city": "metrotaipei",
        }

    def fetch_ntpc_centers():
        session = requests.Session()
        headers = {
            "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "content-type": "application/x-www-form-urlencoded",
            "origin": "https://www.t-sports.ntpc.gov.tw",
            "referer": "https://www.t-sports.ntpc.gov.tw/home.jsp?id=a6af86d2ea26b816",
            "user-agent": "Mozilla/5.0",
        }
        rows = []
        seen_detail_urls = set()
        for page in range(1, 8):
            response = request_ntpc(
                session,
                "POST",
                NTPC_CENTER_URL,
                data={
                    "intpage": "",
                    "id": "a6af86d2ea26b816",
                    "qptdate": "",
                    "qdldate": "",
                    "keyword": "請輸入關鍵字",
                    "page": str(page),
                    "pagesize": "18",
                },
                headers=headers,
                proxies=proxies,
                timeout=60,
            )
            response.raise_for_status()
            links = parse_ntpc_list(response.text)
            if not links:
                break
            for link in links:
                if link["detail_url"] in seen_detail_urls:
                    continue
                seen_detail_urls.add(link["detail_url"])
                detail_response = request_ntpc(
                    session,
                    "GET",
                    link["detail_url"],
                    headers={"referer": NTPC_CENTER_URL, "user-agent": "Mozilla/5.0"},
                    proxies=proxies,
                    timeout=60,
                )
                detail_response.raise_for_status()
                rows.append(
                    parse_ntpc_detail(
                        detail_response.text,
                        link["detail_url"],
                        link["list_title"],
                    )
                )
            if len(links) < 18:
                break
        return pd.DataFrame(rows)

    center_response = requests.get(SPORTS_CENTER_URL, proxies=proxies, timeout=60)
    center_response.raise_for_status()
    raw_centers = pd.read_csv(io.BytesIO(center_response.content))
    if raw_centers.empty:
        raise ValueError("Data Taipei sports center CSV returned no records.")

    centers = raw_centers.rename(
        columns={
            "名稱": "name",
            "郵遞區號": "postal_code",
            "地址": "address",
            "電話": "phone",
            "網址": "website",
            "經度": "lng",
            "緯度": "lat",
        }
    )
    centers["data_time"] = get_tpe_now_time_str()
    centers["city"] = "taipei"
    centers["source_url"] = SPORTS_CENTER_URL
    centers["lng"] = pd.to_numeric(centers["lng"], errors="coerce")
    centers["lat"] = pd.to_numeric(centers["lat"], errors="coerce")
    centers["postal_code"] = centers["postal_code"].astype(str).str.strip()

    people_response = requests.post(
        REALTIME_URL,
        headers={
            "accept": "*/*",
            "content-length": "0",
            "origin": "https://booking-tpsc.sporetrofit.com",
            "referer": "https://booking-tpsc.sporetrofit.com/Home/LocationPeopleNum",
            "x-requested-with": "XMLHttpRequest",
            "user-agent": "Mozilla/5.0",
        },
        proxies=proxies,
        timeout=60,
    )
    people_response.raise_for_status()
    people_payload = people_response.json()
    people = pd.DataFrame(people_payload.get("locationPeopleNums", []))

    if people.empty:
        people = pd.DataFrame(columns=["LID", "lidName"])
    people = people.rename(
        columns={
            "LID": "location_id",
            "lidName": "realtime_name",
            "swPeopleNum": "sw_people_num",
            "swMaxPeopleNum": "sw_max_people_num",
            "gymPeopleNum": "gym_people_num",
            "gymMaxPeopleNum": "gym_max_people_num",
        }
    )
    people["join_name"] = people["realtime_name"].astype(str).str.strip()
    for column in [
        "sw_people_num",
        "sw_max_people_num",
        "gym_people_num",
        "gym_max_people_num",
    ]:
        if column not in people.columns:
            people[column] = pd.NA
        people[column] = pd.to_numeric(people[column], errors="coerce")

    centers["join_name"] = centers["name"].map(normalize_center_name)
    taipei_data = centers.merge(
        people[
            [
                "join_name",
                "location_id",
                "realtime_name",
                "sw_people_num",
                "sw_max_people_num",
                "gym_people_num",
                "gym_max_people_num",
            ]
        ],
        on="join_name",
        how="left",
    )
    taipei_data["sw_usage_rate"] = taipei_data.apply(
        lambda row: parse_capacity_rate(row["sw_people_num"], row["sw_max_people_num"]), axis=1
    )
    taipei_data["gym_usage_rate"] = taipei_data.apply(
        lambda row: parse_capacity_rate(row["gym_people_num"], row["gym_max_people_num"]), axis=1
    )

    ntpc_centers = fetch_ntpc_centers()
    if not ntpc_centers.empty:
        ntpc_centers["data_time"] = get_tpe_now_time_str()
        ntpc_centers["lng"] = pd.to_numeric(ntpc_centers["lng"], errors="coerce")
        ntpc_centers["lat"] = pd.to_numeric(ntpc_centers["lat"], errors="coerce")
        ntpc_centers["join_name"] = ntpc_centers["name"].map(normalize_center_name)

        sportable_venues_response = requests.get(
            SPORTABLE_VENUES_URL,
            headers={"accept": "application/json", "user-agent": "Mozilla/5.0"},
            proxies=proxies,
            timeout=60,
        )
        sportable_venues_response.raise_for_status()
        sportable_venues = pd.DataFrame(sportable_venues_response.json().get("venues", []))
        if not sportable_venues.empty:
            sportable_venues = sportable_venues[
                (sportable_venues["cityId"] == "NWT") & (sportable_venues["status"] == "active")
            ].copy()
            sportable_venues["join_name"] = sportable_venues["venueName"].map(normalize_center_name)

        sportable_people_response = requests.get(
            SPORTABLE_PEOPLE_URL,
            headers={"accept": "application/json", "user-agent": "Mozilla/5.0"},
            proxies=proxies,
            timeout=60,
        )
        sportable_people_response.raise_for_status()
        sportable_people_rows = []
        for item in sportable_people_response.json():
            sportable_people_rows.append(
                {
                    "venueId": item.get("venueId"),
                    "sw_people_num": item.get("swim", {}).get("count"),
                    "sw_max_people_num": item.get("swim", {}).get("capacity"),
                    "gym_people_num": item.get("gym", {}).get("count"),
                    "gym_max_people_num": item.get("gym", {}).get("capacity"),
                }
            )
        sportable_people = pd.DataFrame(sportable_people_rows)

        if not sportable_venues.empty and not sportable_people.empty:
            sportable = sportable_venues.merge(sportable_people, on="venueId", how="left")
            sportable = sportable.rename(
                columns={"venueId": "location_id", "venueName": "realtime_name"}
            )
            ntpc_data = ntpc_centers.merge(
                sportable[
                    [
                        "join_name",
                        "location_id",
                        "realtime_name",
                        "sw_people_num",
                        "sw_max_people_num",
                        "gym_people_num",
                        "gym_max_people_num",
                    ]
                ],
                on="join_name",
                how="left",
            )
        else:
            ntpc_data = ntpc_centers.copy()
    else:
        ntpc_data = pd.DataFrame()

    data = pd.concat([taipei_data, ntpc_data], ignore_index=True, sort=False)
    for column in [
        "sw_people_num",
        "sw_max_people_num",
        "gym_people_num",
        "gym_max_people_num",
    ]:
        data[column] = pd.to_numeric(data[column], errors="coerce")
    data["sw_usage_rate"] = data.apply(
        lambda row: parse_capacity_rate(row["sw_people_num"], row["sw_max_people_num"]), axis=1
    )
    data["gym_usage_rate"] = data.apply(
        lambda row: parse_capacity_rate(row["gym_people_num"], row["gym_max_people_num"]), axis=1
    )
    data = data.dropna(subset=["lng", "lat"]).copy()

    gdata = add_point_wkbgeometry_column_to_df(
        data, x=data["lng"], y=data["lat"], from_crs=4326
    )
    ready_data = gdata[
        [
            "data_time",
            "city",
            "name",
            "postal_code",
            "address",
            "phone",
            "website",
            "source_url",
            "location_id",
            "realtime_name",
            "sw_people_num",
            "sw_max_people_num",
            "sw_usage_rate",
            "gym_people_num",
            "gym_max_people_num",
            "gym_usage_rate",
            "lng",
            "lat",
            "wkb_geometry",
        ]
    ]

    engine = create_engine(ready_data_db_uri)
    save_geodataframe_to_postgresql(
        engine,
        gdata=ready_data,
        load_behavior=load_behavior,
        default_table=default_table,
        history_table=history_table,
        geometry_type="Point",
    )

    update_lasttime_in_data_to_dataset_info(
        engine,
        airflow_dag_id=dag_id,
        lasttime_in_data=ready_data["data_time"].max(),
    )


dag = CommonDag(proj_folder="proj_city_dashboard", dag_folder="sports_center")
dag.create_dag(etl_func=_transfer)
