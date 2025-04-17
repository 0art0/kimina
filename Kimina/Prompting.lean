import Lean

namespace Kimina

/-!

Construct a prompt for the Kimina Prover Preview model according to the template of the `Qwen` models.

-/

inductive Role
 | system | user | assistant
deriving Inhabited, Repr

instance : ToString Role where
  toString
    | .system => "system"
    | .user => "user"
    | .assistant => "assistant"

structure Message where
  role : Role
  content : String
deriving Inhabited, Repr

def applyChatTemplate (messages : List Message) (addGenerationPrompt := true)
    (startToken := "<|im_start|>") (endToken := "<|im_end|>") : String :=
  let mainPrompt := "\n".intercalate (messages.map displayMessage)
  if addGenerationPrompt then
    s!"{mainPrompt}\n{startToken}assistant\n"
  else
    mainPrompt
where
  displayMessage (message : Message) : String :=
    s!"{startToken}{message.role}\n{message.content}\n{endToken}"

def systemMessage : Message := {
  role := .system,
  content := "You are an expert in mathematics and Lean 4."
}

def createUserMessage (formalStatement : String) : Message := Id.run do
  let mut prompt := "Think about and solve the following problem step by step in Lean 4."
  prompt := prompt ++ s!"\n# Formal statement:\n```lean4\n{formalStatement}\n```"
  return {
    role := .user,
    content := prompt
  }

def constructPromptText (formalStatement : String) (addGenerationPrompt := true)
    (startToken := "<|im_start|>") (endToken := "<|im_end|>") : String :=
  applyChatTemplate
    [systemMessage, createUserMessage formalStatement]
    (addGenerationPrompt := addGenerationPrompt)
    (startToken := startToken) (endToken := endToken)

end Kimina
