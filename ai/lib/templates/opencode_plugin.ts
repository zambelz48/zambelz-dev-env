import { spawnSync } from "node:child_process"
import { Plugin } from "@opencode/plugin"

const hookScript = @@HOOK_SCRIPT@@
const watchedTools: readonly string[] = @@TOOLS@@
const checkBefore = @@BEFORE@@
const checkAfter = @@AFTER@@
const timeoutMs = 480000
const maxOutputBytes = 16 * 1024 * 1024

type Reply = {
  decision: string
  message?: string
  warnings?: string[]
}

type ToolEvent = {
  tool: string
  status?: string
  result?: {
    content?: { type: string; text: string }[]
  }
}

function runHook(event: string, payload: unknown, directory: string): Reply {
  const run = spawnSync(hookScript, ["opencode", event], {
    input: JSON.stringify({ directory, event: payload }),
    encoding: "utf8",
    timeout: timeoutMs,
    maxBuffer: maxOutputBytes,
  })

  if (run.error) {
    throw new Error(`zambelz-dev-env hook could not run: ${run.error.message}`)
  }

  if (run.status !== 0) {
    throw new Error(`zambelz-dev-env hook failed (exit ${run.status}): ${run.stderr}`)
  }

  return JSON.parse(run.stdout) as Reply
}

function watched(event: ToolEvent): boolean {
  return watchedTools.includes(event.tool)
}

function appendWarnings(event: ToolEvent, warnings: string[]): void {
  if (event.status !== "completed" || !event.result || warnings.length === 0) {
    return
  }

  const content = event.result.content ?? []

  event.result = { ...event.result, content: [...content, { type: "text", text: warnings.join("\n\n") }] }
}

export default Plugin.define({
  id: "zambelz-dev-env",
  async setup(ctx) {
    const directory = ctx.location.directory

    if (checkBefore) {
      await ctx.tool.hook("execute.before", (event: ToolEvent) => {
        if (!watched(event)) {
          return
        }

        const reply = runHook("execute.before", event, directory)

        if (reply.decision !== "none") {
          throw new Error(reply.message ?? "zambelz-dev-env hook denied the call")
        }
      })
    }

    if (checkAfter) {
      await ctx.tool.hook("execute.after", (event: ToolEvent) => {
        if (!watched(event)) {
          return
        }

        let warnings: string[]

        try {
          warnings = runHook("execute.after", event, directory).warnings ?? []
        } catch (error) {
          warnings = [`WARN: zambelz-dev-env hook failed after ${event.tool}: ${String(error)}`]
        }

        appendWarnings(event, warnings)
      })
    }
  },
})
