import Lean

open Lean Std Internal Parser Tactic Parsec String

abbrev Std.Internal.Parsec.String.takeUntil (text : String) : Parser String :=
  manyChars <| tryCatch (notFollowedBy <| skipString text)
    (csuccess := fun _ => any)
    (cerror := fun _ => fail s!"Detected end sequence {text}")

abbrev Std.Internal.Parsec.String.takeUntilAndSkip (text : String) : Parser String := do
  let s ← takeUntil text
  skipString text
  return s

declare_syntax_cat kimina
syntax tacticSeq : kimina

variable {M} [Monad M] [MonadLiftT IO M] [MonadEnv M] in
def parseTacticSeq (tacticText : String) : M (TSyntax ``tacticSeq) := do
  let stx ← IO.ofExcept <| runParserCategory (← getEnv) `kimina s!"{tacticText}"
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
  reasoningTrace : String
  tacticSuggestions : TSyntax ``tacticSeq

variable {M} [Monad M] [MonadLiftT IO M] [MonadEnv M] in
def parseResponse (prompt fileContents response : String) : M Response := do
  let (reasoningTrace, tacticText) ← IO.ofExcept <| Parser.run (s := response) do
    ws
    skipString prompt
    ws
    skipString "<think>"
    let reasoningTrace ← takeUntilAndSkip "</think>"
    ws
    skipString "```lean4"
    ws
    skipString fileContents
    let tacticText ← takeUntilAndSkip "```"
    ws
    eof
    return ( reasoningTrace, tacticText )
  let tacticSuggestions ← parseTacticSeq tacticText
  return { reasoningTrace, tacticSuggestions }

end Kimina
