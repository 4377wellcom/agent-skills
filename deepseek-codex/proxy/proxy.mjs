import http from 'node:http';
import { createHash, randomUUID } from 'node:crypto';

const UPSTREAM = process.env.UPSTREAM_BASE_URL || 'https://api.deepseek.com/v1';
const API_KEY = process.env.UPSTREAM_API_KEY || '';
const PORT = parseInt(process.env.PORT || '17890');

function toChatMessages(body) {
  const msgs = [];
  if (body.instructions) msgs.push({ role: 'system', content: body.instructions });
  const input = body.input;
  if (typeof input === 'string') {
    msgs.push({ role: 'user', content: input });
  } else if (Array.isArray(input)) {
    for (const item of input) {
      if (item.type === 'message') {
        let role = item.role || 'user';
        if (role === 'developer') role = 'system';
        let content = item.content;
        if (Array.isArray(content)) {
          const texts = content.filter(c => c.type === 'input_text' || c.type === 'output_text').map(c => c.text).join('');
          content = texts || content.map(c => c.text || '').join('');
        }
        msgs.push({ role, content });
      } else if (item.type === 'function_call') {
        msgs.push({ role: 'assistant', content: null, tool_calls: [{ id: item.id, type: 'function', function: { name: item.name, arguments: JSON.stringify(item.arguments) } }] });
      } else if (item.type === 'function_call_output') {
        msgs.push({ role: 'tool', tool_call_id: item.call_id, content: item.output });
      }
    }
  }
  return msgs;
}

function toResponsesId(chatId) {
  return chatId?.startsWith('chatcmpl-') ? chatId.replace('chatcmpl-', 'resp-') : `resp-${randomUUID()}`;
}

function buildResponseStub(respId, chatId, model) {
  return { id: respId, object: 'response', created_at: Math.floor(Date.now() / 1000), status: 'in_progress', error: null, incomplete_details: null, instructions: null, max_output_tokens: null, model: model || '', output: [], parallel_tool_calls: true, temperature: 1.0, tool_choice: 'auto', tools: [], top_p: 1.0, truncation: 'disabled', usage: { input_tokens: 0, output_tokens: 0, total_tokens: 0 }, user: null, metadata: {} };
}

function sse(event, data) {
  return `event: ${event}\ndata: ${JSON.stringify({ type: event, ...data }, null)}\n\n`;
}

http.createServer((req, res) => {
  if (req.method !== 'POST' || !req.url.endsWith('/v1/responses')) {
    res.writeHead(404).end('Not Found');
    return;
  }

  let raw = '';
  req.on('data', c => raw += c);
  req.on('end', async () => {
    let body;
    try { body = JSON.parse(raw); } catch { res.writeHead(400, { 'Content-Type': 'application/json' }).end(JSON.stringify({ error: { message: 'invalid JSON', type: 'invalid_request_error' } })); return; }
    console.error('REQUEST:', JSON.stringify({ model: body.model, has_instructions: !!body.instructions, instructions_role: body.instructions?.role, input_preview: typeof body.input === 'string' ? body.input.slice(0,100) : Array.isArray(body.input) ? body.input.length + ' items, first_role: ' + (body.input[0]?.role||body.input[0]?.type) : typeof body.input, tools_count: body.tools?.length, tool_names: body.tools?.map(t => t.name || t.function?.name), stream: body.stream }));
    // Log what we send to DeepSeek
    const chatMsgs = toChatMessages(body);
    console.error('CHAT_MSGS_ROLES:', chatMsgs.map(m => m.role).join(','));
    const toolNames = (body.tools || []).map(t => t.name || t.function?.name);
    console.error('TOOLS:', JSON.stringify(toolNames));

    const model = body.model;
    if (!model) { res.writeHead(400).end(JSON.stringify({ error: { message: 'model required' } })); return; }

    const isStream = body.stream === true;
    const messages = toChatMessages(body);
    const chatBody = { model, messages, stream: isStream };
    if (body.max_output_tokens) chatBody.max_tokens = body.max_output_tokens;
    if (body.temperature !== undefined) chatBody.temperature = body.temperature;
    if (body.top_p !== undefined) chatBody.top_p = body.top_p;
    if (body.reasoning?.effort) chatBody.reasoning_effort = body.reasoning.effort;
    if (body.tools?.length) chatBody.tools = body.tools.map(t => {
      let fn = t.function ? { ...t.function } : { name: t.name };
      if (!fn.name) return null;  // skip tools without name
      if (t.description && !fn.description) fn.description = t.description;
      if (t.parameters && !fn.parameters) fn.parameters = t.parameters;
      return { type: 'function', function: fn };
    }).filter(Boolean);

    // Disable thinking mode for faster responses
    chatBody.extra_body = { thinking: { type: 'disabled' } };

    const respId = `resp-${randomUUID()}`;

    if (!isStream) {
      // Non-streaming
      try {
        const dsRes = await fetch(`${UPSTREAM}/chat/completions`, {
          method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${API_KEY}` },
          body: JSON.stringify(chatBody)
        });
        const dsJson = await dsRes.json();
        const message = dsJson.choices?.[0]?.message || {};
        const text = message.content || '';
        const toolCalls = message.tool_calls;
        const resp = buildResponseStub(respId, dsJson.id, dsJson.model);
        resp.status = 'completed';
        resp.output = [];
        if (text) {
          resp.output.push({ type: 'message', id: `msg_${randomUUID()}`, status: 'completed', role: 'assistant', content: [{ type: 'output_text', text, annotations: [] }] });
        }
        if (toolCalls) {
          for (const tc of toolCalls) {
            resp.output.push({ type: 'function_call', id: tc.id, status: 'completed', name: tc.function.name, arguments: tc.function.arguments });
          }
        }
        resp.usage = { input_tokens: dsJson.usage?.prompt_tokens || 0, output_tokens: dsJson.usage?.completion_tokens || 0, total_tokens: dsJson.usage?.total_tokens || 0 };
        resp.output_text = text;
        res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify(resp));
      } catch (e) {
        res.writeHead(502).end(JSON.stringify({ error: { message: e.message } }));
      }
      return;
    }

    // Streaming
    res.writeHead(200, { 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive' });
    res.write(sse('response.created', { response: buildResponseStub(respId, null, model) }));
    res.write(sse('response.in_progress', { response: { id: respId, object: 'response', status: 'in_progress' } }));

    try {
      console.error('DEEPSEEK_CHAT_BODY:', JSON.stringify(chatBody).slice(0, 2000));
      const dsRes = await fetch(`${UPSTREAM}/chat/completions`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${API_KEY}` },
        body: JSON.stringify(chatBody)
      });

      if (!dsRes.ok) {
        const errText = await dsRes.text();
        console.error('DEEPSEEK_ERROR:', dsRes.status, errText.slice(0, 500));
        res.write(sse('error', { message: `DeepSeek error: ${dsRes.status}` }));
        res.end();
        return;
      }

      const msgId = `msg_${randomUUID()}`;
      let outputItemAdded = false, contentPartAdded = false, fullText = '', completedSent = false;
      let toolCallItems = {};

      console.error('DEEPSEEK_STREAM_STARTED');
      const reader = dsRes.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      let chunkCount = 0;

      while (true) {
        const { done, value } = await reader.read();
        chunkCount++;
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (!line.startsWith('data: ') || line.includes('[DONE]')) {
            if (line.includes('[DONE]')) break;
            continue;
          }
          try {
            const chunk = JSON.parse(line.slice(6));
            const delta = chunk.choices?.[0]?.delta || {};
            const finish = chunk.choices?.[0]?.finish_reason;

            if (delta.role && !outputItemAdded) {
              outputItemAdded = true;
              res.write(sse('response.output_item.added', { output_index: 0, item: { type: 'message', id: msgId, status: 'in_progress', role: delta.role, content: [] } }));
            }
            if (delta.content) {
              if (!contentPartAdded) {
                contentPartAdded = true;
                res.write(sse('response.content_part.added', { item_id: msgId, output_index: 0, content_index: 0, part: { type: 'output_text', text: '', annotations: [] } }));
              }
              fullText += delta.content;
              res.write(sse('response.output_text.delta', { item_id: msgId, output_index: 0, content_index: 0, delta: delta.content }));
            }
            if (delta.tool_calls) {
              for (const tc of delta.tool_calls) {
                if (tc.id) {
                  toolCallItems[tc.index] = { id: tc.id, name: tc.function?.name || '', args: '', added: false };
                }
                if (toolCallItems[tc.index] && tc.function?.arguments) {
                  const item = toolCallItems[tc.index];
                  item.args += tc.function.arguments;
                  if (!item.added) {
                    item.added = true;
                    res.write(sse('response.output_item.added', { output_index: 1, item: { type: 'function_call', id: item.id, status: 'in_progress', name: item.name, arguments: '' } }));
                    res.write(sse('response.content_part.added', { item_id: item.id, output_index: 1, content_index: 0, part: { type: 'input_output' } }));
                  }
                  res.write(sse('response.output_text.delta', { item_id: item.id, output_index: 1, content_index: 0, delta: tc.function.arguments }));
                }
              }
            }
            if (finish) {
              if (contentPartAdded) {
                res.write(sse('response.output_text.done', { item_id: msgId, output_index: 0, content_index: 0, text: fullText }));
                res.write(sse('response.content_part.done', { item_id: msgId, output_index: 0, content_index: 0, part: { type: 'output_text', text: fullText, annotations: [] } }));
              }
              if (outputItemAdded) {
                res.write(sse('response.output_item.done', { output_index: 0, item: { type: 'message', id: msgId, status: 'completed', role: 'assistant', content: contentPartAdded ? [{ type: 'output_text', text: fullText, annotations: [] }] : [] } }));
              }
              // Complete accumulated tool calls
              const toolOutput = [];
              for (const idx in toolCallItems) {
                const tc = toolCallItems[idx];
                if (tc.added) {
                  res.write(sse('response.output_text.done', { item_id: tc.id, output_index: 1, content_index: 0, text: tc.args }));
                  res.write(sse('response.content_part.done', { item_id: tc.id, output_index: 1, content_index: 0, part: { type: 'input_output' } }));
                  res.write(sse('response.output_item.done', { output_index: 1, item: { type: 'function_call', id: tc.id, status: 'completed', name: tc.name, arguments: tc.args } }));
                }
                toolOutput.push({ type: 'function_call', id: tc.id, status: 'completed', name: tc.name, arguments: tc.args });
              }
              const usage = chunk.usage || { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };
              const streamOutput = [];
              if (contentPartAdded) {
                streamOutput.push({ type: 'message', id: msgId, status: 'completed', role: 'assistant', content: [{ type: 'output_text', text: fullText, annotations: [] }] });
              }
              streamOutput.push(...toolOutput);
              res.write(sse('response.completed', {
                response: {
                  id: respId, object: 'response', created_at: Math.floor(Date.now() / 1000), status: 'completed',
                  output: streamOutput,
                  usage: { input_tokens: usage.prompt_tokens || 0, output_tokens: usage.completion_tokens || 0, total_tokens: usage.total_tokens || 0 }
                }
              }));
              completedSent = true;
            }
          } catch { /* skip parse errors */ }
        }
      }

      console.error('FALLBACK_COMPLETION: outputItemAdded=%s contentPartAdded=%s fullText=%s', outputItemAdded, contentPartAdded, fullText.slice(0, 50));
      // If stream ended without finish_reason (DeepSeek sometimes does this)
      if (!outputItemAdded) outputItemAdded = true;
      if (contentPartAdded && fullText) {
        res.write(sse('response.output_text.done', { item_id: msgId, output_index: 0, content_index: 0, text: fullText }));
        res.write(sse('response.content_part.done', { item_id: msgId, output_index: 0, content_index: 0, part: { type: 'output_text', text: fullText, annotations: [] } }));
      }
      if (fullText || !contentPartAdded) {
        res.write(sse('response.output_item.done', { output_index: 0, item: { type: 'message', id: msgId, status: 'completed', role: 'assistant', content: contentPartAdded ? [{ type: 'output_text', text: fullText, annotations: [] }] : [] } }));
      }
      // Complete any pending tool calls in fallback
      const toolOutput = [];
      for (const idx in toolCallItems) {
        const tc = toolCallItems[idx];
        if (tc.added) {
          res.write(sse('response.output_text.done', { item_id: tc.id, output_index: 1, content_index: 0, text: tc.args }));
          res.write(sse('response.content_part.done', { item_id: tc.id, output_index: 1, content_index: 0, part: { type: 'input_output' } }));
          res.write(sse('response.output_item.done', { output_index: 1, item: { type: 'function_call', id: tc.id, status: 'completed', name: tc.name, arguments: tc.args } }));
        }
        toolOutput.push({ type: 'function_call', id: tc.id, status: 'completed', name: tc.name, arguments: tc.args });
      }
      if (!completedSent) {
        const fallbackOutput = [];
        if (contentPartAdded) {
          fallbackOutput.push({ type: 'message', id: msgId, status: 'completed', role: 'assistant', content: [{ type: 'output_text', text: fullText, annotations: [] }] });
        }
        fallbackOutput.push(...toolOutput);
        res.write(sse('response.completed', {
          response: {
            id: respId, object: 'response', created_at: Math.floor(Date.now() / 1000), status: 'completed',
            output: fallbackOutput,
            usage: { input_tokens: 0, output_tokens: 0, total_tokens: 0 }
          }
        }));
      }
    } catch (e) {
      console.error('PROXY_ERROR:', e.message);
      res.write(sse('error', { message: e.message }));
    }
    res.end();
  });
}).listen(PORT, () => console.log(`Proxy running on http://127.0.0.1:${PORT} -> ${UPSTREAM}`));
