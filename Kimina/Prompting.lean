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

instance : ToString Message where
  toString (msg : Message) :=
    s!"<|im_start|>{msg.role}\n{msg.content}\n<|im_end|>"

def applyChatTemplate (messages : List Message) (addGenerationPrompt := true) : String :=
  let mainPrompt := "\n".intercalate (messages.map toString)
  if addGenerationPrompt then
    s!"{mainPrompt}\n<|im_start|>assistant\n"
  else
    mainPrompt

def systemMessage : Message := {
  role := .system,
  content := "You are an expert in mathematics and Lean 4."
}

def createUserMessage (formalStatement : String) : Message := Id.run do
  let mut prompt := "Think about and solve the following problem step by step in Lean 4."
  prompt := prompt ++ s!"\n# Formal statement:\n```lean4\n{formalStatement}\n```\n"
  return {
    role := .user,
    content := prompt
  }

def constructPromptText (formalStatement : String) (addGenerationPrompt := true) : String :=
  applyChatTemplate
    [systemMessage, createUserMessage formalStatement]
    (addGenerationPrompt := addGenerationPrompt)

end Kimina
