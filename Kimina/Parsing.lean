import Lean

open Lean Std Internal Parser Tactic Parsec String

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

variable {M} [Monad M] [MonadLiftT IO M] [MonadEnv M] in
def parseTacticSeq (tacticText : String) : M (TSyntax ``tacticSeq) := do
  let stx ← IO.ofExcept <| runParserCategory (← getEnv) `kimina tacticText
  return TSyntax.mk stx[0]

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
  tacticSuggestions : TSyntax ``tacticSeq

variable {M} [Monad M] [MonadLiftT IO M] [MonadEnv M]

partial def parseReasoningTrace (reasoningText : String) : M MessageData :=
  IO.ofExcept <| Parser.run (s := reasoningText) do
    let (_, messages) ← parseReasoningTraceCore.run #[]
    return .trace { cls := `kimina, collapsed := false } "Reasoning trace" messages
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

def parseResponse (prompt fileContents response : String) : M Response := do
  let (reasoningText, tacticText) ← IO.ofExcept <| Parser.run (s := response) do
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
    eof
    return ( reasoningText, tacticText )
  let reasoningTrace ← parseReasoningTrace reasoningText
  let tacticSuggestions ← parseTacticSeq tacticText
  return { reasoningTrace, tacticSuggestions }

end Kimina
