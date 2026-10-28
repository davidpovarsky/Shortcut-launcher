# Runtime list editor — iPadOS Shortcuts experiment







## Goal







Determine whether the **add / remove / reorder** list editor photographed in Shortcuts can appear **during execution** of a Shortcuts action instead of only when the user configures a widget/action.







## Critical build finding (Xcode 27)







The original proposal — \`@Parameter(size: .init(min:1,max:8)) var items: [String]?\`, then \`try await $items.requestValue()\` — is **not supported by the SDK**.







The first real IPA build, run \`40790051108\`, failed with:







- \`@Parameter(size:)\` overload requires a supported element such as \`AppEntity\` / \`IntentPerson\` rather than primitive \`String\` (Xcode error \`String and IntentPerson be equivalent\`).



- \`requestValue()\` on \`[String]?\` returns **one \`String\`**, not \`[String]\` (compiler error \`cannot convert String to expected argument type [String]\`).







These are measured compile-time constraints. A string-list editor cannot be summoned by the precise primitive example previously suggested.







## Revised experiments (all should compile)







1. **LAB: Runtime List (Sized Entities)**



   \`@Parameter(size: .init(min:1,max:8)) var items: [RuntimeListSampleEntity]?\`, and **in perform** call \`$items.requestValue(...)\`. The collection is made of selectable sample \`AppEntity\` values because this is an explicitly supported \`size:\` type. The API returns **one selected entity**, so this tests what prompt appears rather than claiming an editable array result.



2. **LAB: Runtime Text List (Plain)**



   \`@Parameter var items: [String]?\`; in perform call \`$items.requestValue(...)\`. The API returns **one \`String\`**, and the output states that clearly.



3. **LAB: Required Sized List**



   \`@Parameter(size: .init(min:1,max:8)) var items: [RuntimeListSampleEntity]\` (required, not optional). This is the **only** experiment where the system resolves a whole collection before \`perform()\` and the resulting output lists all selected elements. Test once with the parameter empty at execution, and once by configuring its value in the Shortcut editor.







All actions return diagnostic plain-text output, suitable for a following **Show Result** action. The sample entities are fixed Hebrew titles; this experiment intentionally does not provide free-form text entry or file attachment.







## iPad test







1. Install IPA from the experiment branch, then create **three separate Shortcuts**, each with one of the above LAB actions followed by **Show Result** on its magic output.



2. Launch **Runtime List (Sized Entities)**. Observe whether \`requestValue\` shows the **add/remove/reorder editor**, a single-choice picker, or a different UI. Do not confuse the editor displayed when configuring the action with a prompt during execution.



3. Run **Runtime Text List (Plain)**. Observe whether it shows a single text prompt (likely), and whether it returns the entered value.



4. Run **Required Sized List** with its parameter unset. Check whether the system asks for a complete list at runtime; if the system instead insists you configure the parameter in the action editor, record that behavior.



5. Edit the **Required Sized List** parameter in the Shortcuts editor and see whether the native add/remove/reorder editor appears *there*. Set two or three entries, change the order, run, and verify the output order.







### What conclusions are justified?







| Observation | Conclusion |



|---|---|



| Sized optional requestValue shows a list editor | The editor can potentially be presented at runtime, but requestValue still yields one element |



| Required sized parameter requests whole list at runtime | Strong evidence that runtime array collection is possible through parameter resolution |



| List editor is shown **only** in the action editor | The list editor cannot serve as a runtime message composer by this method |



| Plain [String]? requestValue shows only a text prompt | Consistent with compiler's single-String return type |







This deliberately isolates the system's UI boundaries before investigating mixing text, images and file import for the AI agent.







## Sources







- Apple API for size (limited AppEntity array initializer): https://developer.apple.com/documentation/appintents/intentparameter/init(title:description:default:size:inputconnectionbehavior:)



- Apple API for requestValue: https://developer.apple.com/documentation/appintents/intentparameter/requestvalue(_:)



- Xcode failure diagnostic: https://github.com/davidpovarsky/Shortcut-launcher/actions/runs/40790051108
