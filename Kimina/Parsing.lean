import Lean

open Lean Std Internal Parser Meta Tactic Parsec String

abbrev Std.Internal.Parsec.String.takeUntil (text : String) : Parser String :=
  manyChars <| tryCatch (notFollowedBy <| skipString text)
    (csuccess := fun _ => any)
    (cerror := fun _ => fail s!"Detected end sequence {text}")

abbrev Std.Internal.Parsec.String.takeUntilAndSkip (text : String) : Parser String := do
  let s ← takeUntil text
  unless ← isEof do skipString text
  return s

declare_syntax_cat kimina
syntax tacticSeq : kimina

def parseTacticSeq (tacticText : String) : CoreM TryThis.SuggestionText := do
  let stx? := runParserCategory (← getEnv) `kimina tacticText
  match stx? with
  | .ok stx => return .tsyntax (kind := ``tacticSeq) <| TSyntax.mk stx[0]
  | .error err =>
    logWarning m!"⚠ The tactic suggestion does not parse in the current context, displaying plain text instead:\n{err}"
    return .string tacticText
namespace Kimina

/-!

# Parsing

Parsing the language model reponse according to the format

[original prompt]
<think>
[reasoning trace]
</think>
```lean4
[current file contents]
[new code]
```

-/

structure Response where
  reasoningTrace : MessageData
  tacticSuggestions : TryThis.SuggestionText

partial def parseReasoningTrace (reasoningText : String) : CoreM MessageData :=
  let parseResult := Parser.run (s := reasoningText) do
    let (_, messages) ← parseReasoningTraceCore.run #[]
    return .trace { cls := `kimina, collapsed := false } "Reasoning trace" messages
  match parseResult with
  | .ok result => return result
  | .error err => do
      logWarning m!"⚠ Parsing reasoning trace failed with error {err}, outputting plain text instead."
      return reasoningText
where
  parseReasoningTraceCore : StateT (Array MessageData) Parser Unit := do
    let text ← takeUntilAndSkip "```tactics"
    modify (·.push text)
    ws
    unless ← (isEof : Parser Bool) do
      let code ← takeUntilAndSkip "```"
      let codeMsg := MessageData.trace
        { cls := `tactics, collapsed := false } "🖥️"
        #[Format.align (force := false), code]
      modify (·.push codeMsg)
      ws
      unless ← (isEof : Parser Bool) do
        parseReasoningTraceCore

def parseResponse (prompt fileContents response : String) : CoreM Response := do
  let parseResult := Parser.run (s := response) do
    ws
    skipString prompt
    ws
    skipString "<think>"
    let reasoningText ← takeUntilAndSkip "</think>"
    ws
    skipString "```lean4"
    ws
    skipString fileContents
    let tacticText ← takeUntilAndSkip "```"
    ws
    skipString "<|im_end|>"
    eof
    return ( reasoningText, tacticText )
  match parseResult with
  | .ok (reasoningText, tacticText) =>
    let reasoningTrace ← parseReasoningTrace reasoningText
    let tacticSuggestions ← parseTacticSeq tacticText
    return { reasoningTrace, tacticSuggestions }
  | .error err =>
    logError m!"Model response:\n{response}"
    throwError "Error in parsing response: {err}\nPlease try running the tactic again to generate a new response."

end Kimina
