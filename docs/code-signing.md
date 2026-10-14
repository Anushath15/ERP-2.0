# Windows code signing: what it is, what is free, what we decided

**Why it matters.** Windows shows "Unknown publisher" / "Windows protected your PC" for programs that are not signed with a certificate that names the publisher. Signing proves *who* published a file and that it was not changed afterwards. It does not prove the program is safe. Until we sign, the README's "Verify your download" (SHA-256 checksums and GitHub build attestations) is how a person checks a file.

## Free option researched: SignPath Foundation (checked 2026-10-14, <https://signpath.org/terms>)
- **Cost:** free for qualifying open-source projects. The page gives no price or quota; acceptance is at their discretion ("under no obligation to accept").
- **Who the publisher is:** the certificate is issued to **SignPath Foundation**, so Windows would show that name, not "Senthil Enterprises". It removes "Unknown publisher" but does not name the shop.
- **Eligibility (their list):** OSI-approved license for everything (we use MIT: OK); no proprietary code; no malware or unwanted programs; actively maintained and **already released in the form to be signed** and documented on its download page; the people who sign must be the people who develop and own the repository; built from source in a verifiable CI build; every team member uses multi-factor authentication; defined roles (author, reviewer, approver) and each signing request approved; a "Code signing policy" section on the project home page with the required attribution and privacy information; product name and version metadata set; the software must respect privacy, announce system changes and be uninstallable.
- **Steps (owner):** (1) turn on two-step verification for the GitHub account, (2) choose and confirm the MIT license stays, (3) apply on <https://signpath.org> (their "Apply" section) with the repository link, (4) add the "Code signing policy" section to the README with their attribution text, (5) when accepted, add a SignPath step to the release workflow after the build and before the owner's approval. The workflow already has one approval gate (the `release` environment), which satisfies their "each request approved" rule.
- **Likely snag:** the project must already be released and maintained, and a shop-specific ERP with one user may be judged too small. Apply after the first real (non-prototype) release.

## Paid options (nothing bought)
Individual Authenticode/OV certificates from commercial authorities and Azure Trusted Signing exist; prices change and some need a registered business with years of history. Not recommended before the shop actually distributes the program to other people.

## Decision
No signing now. The program is installed only by the owner on the shop's own computers, from a release he approved himself, after the checksum check. Re-open this when the program is given to anyone else. **Nothing was purchased and no application was sent.**
