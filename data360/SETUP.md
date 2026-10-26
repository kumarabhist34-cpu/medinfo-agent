# Data 360 setup

Data 360 configuration is done in Setup and Data 360 app screens, not in source code, so this guide records every step. Screenshot each finished step into `docs/screenshots/` as evidence for your README.

Some Data 360 features consume credits or may be limited in a Developer Edition org. If a step is unavailable, use an Agentforce trial org or Trailhead playground for that step and note it in the README.

## 1. Load the CRM side

1. Deploy this project (see the main README), then import `data/hcp_contacts.csv` into Contacts with Data Import Wizard. Map `Licence_Number__c` to **Licence Number**; leave `Specialty` unmapped or map it to Description.
2. In Data 360 setup, connect the **Salesforce CRM** data source and create a data stream for **Contact**. This creates a data lake object (DLO) for Contact.

## 2. Ingest the second source

1. Create a data stream from `data/conference_attendees.csv` (file upload, or Amazon S3 / Google Cloud Storage if you prefer a connector).
2. Category: **Profile**. Primary key: `registration_no`.
3. This creates a second DLO, `Conference_Attendees`.

## 3. Map DLOs to DMOs

| Source field | Data model object (DMO) | DMO field |
| --- | --- | --- |
| Contact.Id / registration_no | Individual | Individual Id |
| FirstName, LastName / full_name | Individual | First Name, Last Name (split full_name with a formula field first) |
| Email / email | Contact Point Email | Email Address |
| Phone / mobile | Contact Point Phone | Telephone Number |
| Licence_Number__c / registration_no | Party Identification | Identification Number (type: Medical Licence) |

Tip: normalise phone numbers in a formula field (strip spaces) before mapping, otherwise `+91 90000 10003` and `+919000010003` will not match.

## 4. Identity resolution

Create an identity resolution ruleset on Individual:

1. **Match rule 1:** exact normalised email.
2. **Match rule 2:** exact Party Identification (licence number) + fuzzy first name.
3. **Match rule 3:** exact normalised phone + exact last name.
4. **Reconciliation:** prefer the CRM source for name and email (most recent for phone).

Run it and record the numbers for your README and resume:

| Metric | Before | After |
| --- | --- | --- |
| Source profiles | 50 | 50 |
| Unified individuals | 50 | expected 40 (10 attendees merge into existing HCPs) |
| Consolidation rate | 0% | ~20% |

If the result differs from 40, look at which pairs didn't merge and explain why in the README. That debugging story is good interview material.

## 5. Calculated insight and data action (real-time activation)

1. Calculated insight `HCP_Engagement__cio`: sessions attended per unified individual (sum of `sessions_attended`).
2. Data action: when an HCP's engagement exceeds 4 sessions, trigger a Platform Event or Flow that creates a follow-up Task for the medical science liaison.

## 6. Label PDFs: unstructured data, search index, retriever

1. Download 3-5 public label PDFs from DailyMed (dailymed.nlm.nih.gov), for example metformin, atorvastatin and lisinopril.
2. Upload them as **unstructured data** (file upload or a cloud storage connector). This creates an unstructured DLO and an unstructured DMO.
3. In **Intelligent Context**, test parsing on one PDF, then enable enriched indexing.
4. Create a **search index** on the unstructured DMO. Choose **hybrid search**: it combines keyword and vector matching, so exact drug names and doses ("500 mg") are matched, not just similar meanings.
5. Create a **retriever** on that index, limited to the label content.
6. In Prompt Builder, create a Flex template `MedInfo_Answer_From_Label` with one text input `question`. Ground it with the retriever, and instruct it to answer only from retrieved passages and name the label section used. This is the template the agent's `answer_from_label` action targets.

## 7. Evidence checklist

- [ ] Screenshot of both data streams
- [ ] Screenshot of the DMO mappings
- [ ] Identity resolution summary with your real before/after numbers
- [ ] Search index and retriever configuration
- [ ] Prompt template preview answering a dosing question with a cited section
