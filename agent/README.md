# The agent

`MedInfo_Agent.agent` is the agent's blueprint in Agent Script: topics (subagents), instructions, variables and actions.

## Load it into your org with Agentforce DX

1. Install the Salesforce CLI and the Agentforce DX VS Code extension.
2. Generate an authoring bundle for an agent named `MedInfo_Agent` (in VS Code: **AFDX: Create Authoring Bundle**, or `sf agent generate authoring-bundle --help` for the CLI flags in your CLI version).
3. Replace the generated `.agent` file in `force-app/main/default/aiAuthoringBundles/MedInfo_Agent/` with this file.
4. Fix anything the Agent Script validator underlines. Agent Script is new and its syntax is still changing between releases; this file follows the Salesforce Agent Script reference as of October 2026.
5. Preview it (right-click the file, **AFDX: Preview This Agent**), then publish it to the org and open it in Agentforce Builder.

## Design decisions (good interview material)

- **Adverse events are routed first and unconditionally.** The router sends any adverse-event mention to `Adverse_Event` even before the HCP is verified, and the Apex action always assigns the Case to the Adverse Events queue. The LLM never decides whether a report reaches a human.
- **Verification gates product answers.** `Drug_Information` and `Label_Updates` are only available when `hcp_verified` is true, so an unverified user can't get label content.
- **Answers come only from retrieved label passages.** `answer_from_label` targets a prompt template grounded by the Data 360 retriever; instructions forbid answering beyond it.
- **Each action logs once.** `log_adverse_event` is available only while `ae_case_number` is empty, so a long conversation can't create duplicate cases.

## Tests

`tests/MedInfo_Agent_Tests.yaml` lists test utterances with the expected subagent and action. Create the test in your org with `sf agent test create` (pass the spec file) and run it with `sf agent test run`. Check `sf agent test --help` for the exact flags in your CLI version.
