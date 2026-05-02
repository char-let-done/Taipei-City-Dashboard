package controllers

import (
	"TaipeiCityDashboardBE/app/models"
	"TaipeiCityDashboardBE/app/services/ai"
	"TaipeiCityDashboardBE/app/util"
	"context"
	"encoding/json"
	"fmt"
	"html"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tmc/langchaingo/llms"
)

// AIChatInput matches the Request Schema in specification。https://docs.twcloud.ai/docs/user-guides/twcc/afs/api-and-parameters/api-parameter-information#模型說明
type AIChatInput struct {
	SessionID string `json:"session"`
	Stream    bool   `json:"stream"`
	Messages  []struct {
		Role      string `json:"role" binding:"required,oneof=system user assistant tool"`
		Content   string `json:"content" binding:"required"`
		ToolCalls []struct {
			ID       string `json:"id"`
			Type     string `json:"type"`
			Function struct {
				Name      string `json:"name"`
				Arguments string `json:"arguments"`
			} `json:"function"`
		} `json:"tool_calls,omitempty"`
		ToolCallID string `json:"tool_call_id,omitempty"`
	} `json:"messages" binding:"required,gt=0"`
	MaxNewTokens     *int      `json:"max_new_tokens" binding:"omitempty,gt=0"`
	Temperature      *float64  `json:"temperature" binding:"omitempty,gt=0"`
	TopP             *float64  `json:"top_p" binding:"omitempty,gt=0,lte=1"`
	TopK             *int      `json:"top_k" binding:"omitempty,gte=1,lte=100"`
	FrequencePenalty *float64  `json:"frequence_penalty" binding:"omitempty,gt=0"`
	StopSequences    []string  `json:"stop_sequences" binding:"omitempty,max=4"`
	Seed             *int      `json:"seed" binding:"omitempty,gte=0"`
	Tools            []struct {
		Type     string `json:"type" binding:"required,eq=function"`
		Function struct {
			Name        string      `json:"name" binding:"required"`
			Description string      `json:"description,omitempty"`
			Parameters  interface{} `json:"parameters,omitempty"`
		} `json:"function" binding:"required"`
	} `json:"tools,omitempty"`
	ToolChoice interface{} `json:"tool_choice,omitempty"`
}

// ChatWithTWCC is the controller for POST /api/v1/ai/chat/twai
func ChatWithTWCC(c *gin.Context) {
	var input AIChatInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":     "error",
			"error_code": "INVALID_REQUEST",
			"message":    err.Error(),
		})
		return
	}

	// 1. Session ID Management
	sessionID := input.SessionID
	if sessionID == "" {
		sessionID = "session_" + util.GenerateRandomString(10)
	}
	sessionID = html.EscapeString(sessionID)

	// 2. Prepare AI Request
	_, accountID, _, _, _ := util.GetUserInfoFromContext(c)
	req := ai.AIChatRequest{
		SessionID: sessionID,
		UserID:    fmt.Sprintf("%d", accountID),
		IPAddress: c.ClientIP(),
		Messages:  input.ToServiceMessages(),
	}

	// 3. Prepare Dynamic Options
	options := input.ToCallOptions()

	// 4. Handle Streaming Response
	if input.Stream {
		c.Header("Content-Type", "text/event-stream")
		c.Header("Cache-Control", "no-cache")
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("Connection", "keep-alive")

		// Add Streaming Callback
		options = append(options, llms.WithStreamingFunc(func(ctx context.Context, chunk []byte) error {
			if string(chunk) == ": heartbeat\n\n" {
				return nil
			}
			_, err := c.Writer.Write(chunk)
			if err != nil {
				return err
			}
			c.Writer.Flush()
			return nil
		}))

		_, err := ai.ChatWithTWCC(c.Request.Context(), req, options...)
		if err != nil {
			if !c.Writer.Written() {
				c.JSON(http.StatusInternalServerError, gin.H{
					"status":     "error",
					"error_code": "AI_SERVICE_STREAM_ERROR",
					"message":    err.Error(),
				})
			}
		}
		return
	}

	// 5. Standard Non-Streaming Response
	logEntry, err := ai.ChatWithTWCC(c.Request.Context(), req, options...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":     "error",
			"error_code": "AI_SERVICE_ERROR",
			"message":    err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data": gin.H{
			"session":       logEntry.SessionID,
			"content":       logEntry.Answer,
			"usage": gin.H{
				"input_tokens":  logEntry.InputTokens,
				"output_tokens": logEntry.OutputTokens,
				"total_tokens":  logEntry.TotalTokens,
			},
			"tool_used":  logEntry.ToolUsed,
			"latency_ms": logEntry.LatencyMS,
			"model":      logEntry.Model,
			"provider":   logEntry.Provider,
		},
	})
}

// ToServiceMessages converts input messages to langchaingo internal format
func (input *AIChatInput) ToServiceMessages() []llms.MessageContent {
	serviceMsgs := make([]llms.MessageContent, 0)
	for _, m := range input.Messages {
		role := llms.ChatMessageTypeHuman
		var parts []llms.ContentPart
		parts = append(parts, llms.TextContent{Text: m.Content})

		switch m.Role {
		case "assistant":
			role = llms.ChatMessageTypeAI
			if len(m.ToolCalls) > 0 {
				for _, tc := range m.ToolCalls {
					parts = append(parts, llms.ToolCall{
						ID:   tc.ID,
						Type: tc.Type,
						FunctionCall: &llms.FunctionCall{
							Name:      tc.Function.Name,
							Arguments: tc.Function.Arguments,
						},
					})
				}
			}
		case "system":
			role = llms.ChatMessageTypeSystem
		case "tool":
			role = llms.ChatMessageTypeTool
			parts = []llms.ContentPart{llms.ToolCallResponse{
				ToolCallID: m.ToolCallID,
				Content:    m.Content,
			}}
		}

		serviceMsgs = append(serviceMsgs, llms.MessageContent{
			Role:  role,
			Parts: parts,
		})
	}
	return serviceMsgs
}

// ToCallOptions extracts and maps AI generation options and tools
func (input *AIChatInput) ToCallOptions() []llms.CallOption {
	options := make([]llms.CallOption, 0)
	params := make(map[string]interface{})

	// Map numerical parameters
	if input.MaxNewTokens != nil {
		options = append(options, llms.WithMaxTokens(*input.MaxNewTokens))
		params["max_new_tokens"] = *input.MaxNewTokens
	}
	if input.Temperature != nil {
		options = append(options, llms.WithTemperature(*input.Temperature))
		params["temperature"] = *input.Temperature
	}
	if input.TopP != nil {
		options = append(options, llms.WithTopP(*input.TopP))
		params["top_p"] = *input.TopP
	}
	if input.TopK != nil {
		options = append(options, llms.WithTopK(*input.TopK))
		params["top_k"] = *input.TopK
	}
	if input.FrequencePenalty != nil {
		options = append(options, llms.WithRepetitionPenalty(*input.FrequencePenalty))
		params["frequence_penalty"] = *input.FrequencePenalty
	}
	if len(input.StopSequences) > 0 {
		options = append(options, llms.WithStopWords(input.StopSequences))
		params["stop_sequences"] = input.StopSequences
	}
	if input.Seed != nil {
		params["seed"] = *input.Seed
	}

	// Map Tools
	if len(input.Tools) > 0 {
		lt := make([]llms.Tool, 0)
		for _, t := range input.Tools {
			lt = append(lt, llms.Tool{
				Type: t.Type,
				Function: &llms.FunctionDefinition{
					Name:        t.Function.Name,
					Description: t.Function.Description,
					Parameters:  t.Function.Parameters,
				},
			})
		}
		options = append(options, llms.WithTools(lt))
		if input.ToolChoice != nil {
			options = append(options, llms.WithToolChoice(input.ToolChoice))
		}
	}

	if len(params) > 0 {
		options = append(options, llms.WithMetadata(params))
	}

	return options
}

// ---------- GeoQuery ----------

var districtNames = []string{
	"中山區", "中正區", "信義區", "內湖區", "北投區", "南港區",
	"士林區", "大同區", "大安區", "文山區", "松山區", "萬華區",
	"三峽區", "三芝區", "三重區", "中和區", "五股區", "八里區",
	"土城區", "坪林區", "平溪區", "新店區", "新莊區", "板橋區",
	"林口區", "樹林區", "永和區", "汐止區", "泰山區", "淡水區",
	"深坑區", "烏來區", "瑞芳區", "石碇區", "石門區", "萬里區",
	"蘆洲區", "貢寮區", "金山區", "雙溪區", "鶯歌區",
}

const geoQuerySystemPrompt = `你是一位台北城市儀表板的數據助理。請根據使用者的問題、可用的行政區列表、以及相關組件的數據，以 JSON 格式回覆。

可用的行政區列表：
中山區、中正區、信義區、內湖區、北投區、南港區、士林區、大同區、大安區、文山區、松山區、萬華區、三峽區、三芝區、三重區、中和區、五股區、八里區、土城區、坪林區、平溪區、新店區、新莊區、板橋區、林口區、樹林區、永和區、汐止區、泰山區、淡水區、深坑區、烏來區、瑞芳區、石碇區、石門區、萬里區、蘆洲區、貢寮區、金山區、雙溪區、鶯歌區

輸出格式必須是以下 JSON，不要有任何其他文字或 markdown 格式：
{
  "location": "行政區名稱，若問題中沒有提到任何行政區則填 null",
  "selected_component_indices": ["組件index_1", "組件index_2", ...],
  "summary": "一段根據實際數字生成的純事實總結，使用繁體中文"
}

規則：
1. location 必須是上面列表中的名稱，或 null。
2. selected_component_indices 從提供的組件中選出最相關的 1-3 個。
3. summary 必須基於實際 chart 數據，不要臆測。若數據中找不到該行政區的資料，請如實說明。
4. 只輸出 JSON，不要有任何其他文字。`

type geoQueryInput struct {
	Query string `json:"query" binding:"required"`
}

type geoQueryLLMOutput struct {
	Location                 string   `json:"location"`
	SelectedComponentIndices []string `json:"selected_component_indices"`
	Summary                  string   `json:"summary"`
}

func extractJSONFromMarkdown(text string) string {
	re := regexp.MustCompile("(?s)```(?:json)?\\s*(\\{.*?\\})\\s*```")
	matches := re.FindStringSubmatch(text)
	if len(matches) >= 2 {
		return matches[1]
	}
	// Try to find raw JSON object
	start := strings.Index(text, "{")
	end := strings.LastIndex(text, "}")
	if start >= 0 && end > start {
		return text[start : end+1]
	}
	return text
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func defaultTimeRange() (string, string) {
	layout := "2006-01-02T15:04:05+08:00"
	timeFrom := time.Date(1990, 1, 1, 0, 0, 0, 0, time.FixedZone("UTC+8", 8*60*60)).Format(layout)
	timeTo := time.Now().Format(layout)
	return timeFrom, timeTo
}

type simplifiedComponent struct {
	Index   string      `json:"index"`
	Name    string      `json:"name"`
	City    string      `json:"city"`
	Desc    string      `json:"description"`
	Chart   interface{} `json:"chart_data"`
}

func simplifyChartData(queryType string, raw interface{}) interface{} {
	switch queryType {
	case "two_d":
		if out, ok := raw.([]models.TwoDimensionalDataOutput); ok && len(out) > 0 {
			data := out[0].Data
			if len(data) > 20 {
				data = data[:20]
			}
			return gin.H{"type": "two_d", "data": data}
		}
	case "three_d", "percent":
		// raw is gin.H{"data": ..., "categories": ...}
		if m, ok := raw.(gin.H); ok {
			return gin.H{"type": queryType, "data": m["data"], "categories": m["categories"]}
		}
	case "time":
		if out, ok := raw.([]models.TimeSeriesDataOutput); ok {
			truncated := make([]models.TimeSeriesDataOutput, 0, len(out))
			for _, series := range out {
				data := series.Data
				if len(data) > 5 {
					data = data[len(data)-5:]
				}
				truncated = append(truncated, models.TimeSeriesDataOutput{Name: series.Name, Data: data})
			}
			return gin.H{"type": "time", "data": truncated}
		}
	case "map_legend":
		if out, ok := raw.([]models.MapLegendData); ok {
			return gin.H{"type": "map_legend", "data": out}
		}
	}
	return raw
}

// GeoQuery handles natural language map queries.
// POST /api/v1/ai/chat/geo-query
func GeoQuery(c *gin.Context) {
	var input geoQueryInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "error",
			"message": err.Error(),
		})
		return
	}

	// 1. Vector search for components
	scores, err := models.GetComponentByQueryVector(input.Query, 10, 0.8)
	if err != nil || len(scores) == 0 {
		c.JSON(http.StatusOK, gin.H{"status": "success", "fallback": true})
		return
	}

	timeFrom, timeTo := defaultTimeRange()

	// 2. Fetch full component details and chart data
	var components []simplifiedComponent
	for _, s := range scores[:min(5, len(scores))] {
		detail, err := models.GetComponentByID(int(s.ID), s.City)
		if err != nil {
			continue
		}

		queryType, queryString, err := models.GetComponentChartDataQuery(int(s.ID), s.City)
		if err != nil || queryString == "" {
			components = append(components, simplifiedComponent{
				Index: detail.Index,
				Name:  detail.Name,
				City:  detail.City,
				Desc:  detail.ShortDesc,
			})
			continue
		}

		var rawData interface{}
		switch queryType {
		case "two_d":
			d, _ := models.GetTwoDimensionalData(&queryString, timeFrom, timeTo)
			rawData = d
		case "three_d", "percent":
			d, cats, _ := models.GetThreeDimensionalData(&queryString, timeFrom, timeTo)
			rawData = gin.H{"data": d, "categories": cats}
		case "time":
			d, _ := models.GetTimeSeriesData(&queryString, timeFrom, timeTo)
			rawData = d
		case "map_legend":
			d, _ := models.GetMapLegendData(&queryString, timeFrom, timeTo)
			rawData = d
		}

		components = append(components, simplifiedComponent{
			Index: detail.Index,
			Name:  detail.Name,
			City:  detail.City,
			Desc:  detail.ShortDesc,
			Chart: simplifyChartData(queryType, rawData),
		})
	}

	if len(components) == 0 {
		c.JSON(http.StatusOK, gin.H{"status": "success", "fallback": true})
		return
	}

	// 3. Build prompt
	compJSON, _ := json.Marshal(components)
	userPrompt := fmt.Sprintf(
		"使用者問題：%s\n\n相關組件與數據：%s",
		input.Query,
		string(compJSON),
	)

	// 4. Call LLM
	req := ai.AIChatRequest{
		SessionID: "geoquery_" + util.GenerateRandomString(10),
		UserID:    "0",
		IPAddress: c.ClientIP(),
		Messages: []llms.MessageContent{
			{
				Role:  llms.ChatMessageTypeSystem,
				Parts: []llms.ContentPart{llms.TextContent{Text: geoQuerySystemPrompt}},
			},
			{
				Role:  llms.ChatMessageTypeHuman,
				Parts: []llms.ContentPart{llms.TextContent{Text: userPrompt}},
			},
		},
	}

	// Use a moderate temperature and limit tokens for structured output
	options := []llms.CallOption{
		llms.WithTemperature(0.3),
		llms.WithMaxTokens(1024),
	}

	logEntry, err := ai.ChatWithTWCC(c.Request.Context(), req, options...)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"status": "success", "fallback": true})
		return
	}

	// 5. Parse LLM JSON response
	jsonText := extractJSONFromMarkdown(logEntry.Answer)
	var llmResp geoQueryLLMOutput
	if err := json.Unmarshal([]byte(jsonText), &llmResp); err != nil {
		c.JSON(http.StatusOK, gin.H{"status": "success", "fallback": true})
		return
	}

	// If no location found, fallback
	if llmResp.Location == "" || llmResp.Location == "null" {
		c.JSON(http.StatusOK, gin.H{"status": "success", "fallback": true})
		return
	}

	// 6. Resolve location coordinates
	center, ok := models.ResolveDistrictCenter(llmResp.Location)
	if !ok {
		c.JSON(http.StatusOK, gin.H{"status": "success", "fallback": true})
		return
	}

	// 7. Gather selected full components (with map_config)
	var selectedComponents []models.CityComponent
	if len(llmResp.SelectedComponentIndices) == 0 {
		// Fallback to top 3
		for _, s := range scores[:min(3, len(scores))] {
			detail, err := models.GetComponentByID(int(s.ID), s.City)
			if err == nil {
				selectedComponents = append(selectedComponents, detail)
			}
		}
	} else {
		for _, idx := range llmResp.SelectedComponentIndices {
			for _, s := range scores {
				if s.Index == idx {
					detail, err := models.GetComponentByID(int(s.ID), s.City)
					if err == nil {
						selectedComponents = append(selectedComponents, detail)
					}
					break
				}
			}
		}
	}

	if len(selectedComponents) == 0 {
		c.JSON(http.StatusOK, gin.H{"status": "success", "fallback": true})
		return
	}

	// 8. Return structured response
	c.JSON(http.StatusOK, gin.H{
		"status":   "success",
		"fallback": false,
		"location": gin.H{
			"name": llmResp.Location,
			"lng":  center.Lng,
			"lat":  center.Lat,
			"zoom": center.Zoom,
		},
		"components": selectedComponents,
		"summary":    llmResp.Summary,
	})
}
