# Knowledge Sources for IBM Bob Modes and Skills

## Purpose

This document explains where the knowledge used by this IBM Bob configuration
comes from. It separates:

- **Artifact provenance**: who created or accepted the repository content.
- **Knowledge sources**: standards, frameworks, methods, and product
  documentation that informed the behavior of modes and skills.
- **Runtime source priority**: how Bob should choose between local skills,
  MCP tools, external sources, and model knowledge during a conversation.

The mode and skill files in this repository are maintainer-authored,
AI-assisted configuration artifacts. They are not copied from the referenced
standards or websites. External sources are used as conceptual references and
should be consulted directly when exact wording, certification requirements,
current version details, or license terms matter. License and terms handling
for these resources is tracked separately in
[`RESOURCE_LICENSES.md`](RESOURCE_LICENSES.md).

## Repository Content Provenance

The distributable content is recorded in
[`../../CONTENT_PROVENANCE.md`](../../CONTENT_PROVENANCE.md). In summary:

| Artifact Group | Repository Location | Provenance |
| --- | --- | --- |
| Bob custom modes | `../custom_modes.yaml` | AI-assisted, authored, reviewed, and accepted by Thomas Suedbroecker |
| Bob skills | `../skills/` | AI-assisted, authored, reviewed, and accepted by Thomas Suedbroecker |
| Bob documentation and notes | `./`, `../notes/` | AI-assisted, maintained by Thomas Suedbroecker |
| GitHub issue scripts | `../scripts/` | AI-assisted scripts maintained by Thomas Suedbroecker |
| Diagrams and images | `diagramms/`, `../images/` | AI-assisted diagram material accepted by Thomas Suedbroecker |
| GitHub MCP dependency | `../mcp.json` | Runtime npm dependency documented in `../../THIRD_PARTY_NOTICES.md` |

## Runtime Knowledge Priority

All modes should apply this knowledge priority:

1. **User intent and active repository evidence**: the user's current request,
   files, code, docs, tests, configuration, and issue context.
2. **Project-local Bob skills**: files under `../skills/`.
3. **Project-local documentation**: guides under `./`, `guides/`, `diagramms/`,
   and `../notes/`.
4. **Configured tools and MCP sources**: for example GitHub MCP configured in
   `../mcp.json`.
5. **Authoritative external sources**: official product docs, standards,
   specifications, and recognized framework documentation.
6. **General model knowledge**: only when the above sources do not cover the
   task, and with assumptions stated explicitly.

When source currency matters, Bob should use browser or tool-based research
through the Configuration Gap Detector workflow before proposing new skills or
standards-based guidance.

## Mode Knowledge Map

| Mode | Local Knowledge Source | External / Conceptual Sources | Notes |
| --- | --- | --- | --- |
| Architecture Review (`arch-review`) | `sdlc-discovery-gap-analysis-skill.md`, seven architecture review skills, `README-ARCHITECTURE-REVIEW.md`, architecture review guides | C4 Model, arc42, ADR practice, OWASP, NIST SSDF, Twelve-Factor App, DDD, SOLID, cloud architecture patterns | Orchestrates local skills. It should classify SDLC phase and review scope before findings. |
| Spec-Driven Development (`sdd`) | `sdlc-discovery-gap-analysis-skill.md`, `requirements-management-skill.md`, `requirements-traceability-skill.md`, `SDD-README.md`, SDD guides | IBM Bob docs, IBM spec-driven development article, ISO/IEC/IEEE 29148, IREB CPRE, SWEBOK, BDD, DDD, TDD, NIST AI RMF, NIST Generative AI Profile, OWASP LLM Top 10, NIST SSDF | Uses local requirements and traceability skills before implementation prompts or issue preparation. AI Integration and Usage is treated as an SDLC concern when AI tools, models, agents, MCP servers, prompts, or generated-code provenance affect delivery risk. Traceability matrices are limited to GitHub issues, Markdown documents, and code entries. |
| Security & Threat Modeling (`security-review`) | `SKILLS/sdd-security-threat-modeling/SKILL.md` | OWASP Top 10, OWASP ASVS, OWASP threat modeling guidance, STRIDE, ISO 27001, GDPR, HIPAA, PCI DSS, SOC 2 | Standards are conceptual anchors. Exact compliance requirements must be verified for the target jurisdiction and version. |
| Scalability & Performance (`scalability-review`) | `SKILLS/sdd-scalability-performance/SKILL.md` | SRE capacity planning concepts, caching, load balancing, queueing, database performance, autoscaling patterns | Uses engineering patterns and measurable NFRs from the repository context. |
| Architecture Patterns (`patterns-review`) | `SKILLS/sdd-architecture-patterns/SKILL.md` | DDD, CQRS, Event Sourcing, SOLID, GoF patterns, enterprise integration patterns, API design practices, hexagonal and clean architecture | Evaluates fit, not pattern adoption for its own sake. |
| Maintainability & Technical Debt (`maintainability-review`) | `SKILLS/sdd-maintainability-technical-debt/SKILL.md` | Maintainability metrics, refactoring practice, code complexity, testability, modularity, technical-debt management | Findings should be evidence-based from code and docs. |
| Documentation Review (`documentation-review`) | `SKILLS/sdd-documentation-review/SKILL.md`, `LICENSE_DOCUMENTATION.md`, `THIRD_PARTY_NOTICES.md`, `CONTENT_PROVENANCE.md`, `Modes/SDD/documentation/RESOURCE_LICENSES.md`, this knowledge-source map | ADRs, C4 Model, UML, OpenAPI, AsyncAPI, runbooks, documentation-as-code practice, SPDX, CycloneDX, GitHub dependency graph/SBOM, npm registry metadata, PyPI metadata | Reviews completeness, currency, usability, license notice coverage, and content-provenance evidence for project documentation. |
| 12-Factor Compliance (`twelve-factor-review`) | `SKILLS/sdd-twelve-factor-compliance/SKILL.md` | The Twelve-Factor App methodology, cloud-native configuration and operational practices | Applies the twelve factors as a cloud-readiness checklist. |
| Business Alignment (`business-alignment-review`) | `SKILLS/sdd-business-alignment/SKILL.md` | Business capability mapping, quality attributes, stakeholder analysis, ROI/TCO, value and risk analysis | Connects technical choices to stakeholder outcomes and business constraints. |
| Configuration Gap Detector (`config-gap-detector`) | `Modes/SDD/specifiction-driven-development-mode.yaml`, skill inventory, configuration-gap workflow, this knowledge-source map, `Modes/SDD/documentation/RESOURCE_LICENSES.md` when new sources are proposed | Official docs, standards bodies, framework docs, product docs, vendor docs | Researches missing modes, skills, or resources before proposing additions, including evidence-resource and license-boundary updates for new mode or skill sources. |
| GitHub Issue Generator (`github-issue-generator`) | `SKILLS/sdd-github-issue-traceability/SKILL.md`, `SKILLS/sdd-requirements-management/SKILL.md`, `SKILLS/sdd-requirements-traceability/SKILL.md`, `Modes/SDD/scripts/README.md`, GitHub issue scripts | GitHub issue and label conventions, GitHub REST API, GitHub MCP documentation, SDLC traceability practice | Uses Python scripts for batch workflows and legacy MCP for optional interactive use. GitHub issues are the only supported work-item traceability carrier. |

## Skill Knowledge Map

| Skill | Local Purpose | Primary Knowledge Sources | Source Type |
| --- | --- | --- | --- |
| `sdlc-discovery-gap-analysis-skill.md` | Clarify user intent, classify SDLC phase including AI integration and usage, select modes and skills, detect gaps | ISO/IEC/IEEE 29148, SWEBOK, IREB CPRE, C4 Model, arc42, ADRs, OWASP, NIST SSDF, Twelve-Factor App, IBM Bob docs, IBM spec-driven development guidance, NIST AI RMF, NIST Generative AI Profile, OWASP LLM Top 10 | Standards, frameworks, official guidance, local workflow design |
| `requirements-management-skill.md` | Elicit, document, prioritize, validate, and trace requirements | ISO/IEC/IEEE 29148, IBM Requirements Management, IREB CPRE, IEEE 830 history, MoSCoW, Kano, WSJF, BDD | Standards, vendor guidance, established methods |
| `requirements-traceability-skill.md` | Validate forward, backward, and bidirectional traceability | Markdown traceability matrices, GitHub issue workflow, code-entry references, coverage metrics, SDLC audit practice | Established engineering practice and local workflow design with explicit carrier restriction |
| `github-issue-traceability-skill.md` | Map requirements to GitHub issue hierarchy and implementation/test links | GitHub issue conventions, SDLC traceability, requirement ID practices, commit reference conventions, code comments | Tool practice and local workflow design with GitHub as the only supported issue carrier |
| `business-alignment-skill.md` | Evaluate technology alignment with stakeholder value and business goals | Business capability mapping, quality attribute analysis, ROI/TCO, stakeholder analysis, risk management | Established architecture and business-analysis practice |
| `security-threat-modeling-skill.md` | Review threats, controls, and security requirements | OWASP Top 10, OWASP ASVS, OWASP threat modeling, STRIDE, ISO 27001, GDPR, HIPAA, PCI DSS, SOC 2 | Official guidance, standards, regulatory/compliance frameworks |
| `scalability-performance-skill.md` | Review capacity, performance, bottlenecks, and resource efficiency | Performance engineering, SRE capacity planning, caching, load balancing, database tuning, asynchronous processing | Established engineering practice |
| `architecture-patterns-skill.md` | Review architecture style, design patterns, integration, and data patterns | DDD, CQRS, Event Sourcing, SOLID, GoF patterns, enterprise integration patterns, REST, GraphQL, gRPC, hexagonal architecture, clean architecture | Established architecture patterns and API practices |
| `maintainability-technical-debt-skill.md` | Review complexity, coupling, duplication, testability, and debt | Refactoring practice, code quality metrics, modularity, technical debt management, test coverage analysis | Established engineering practice |
| `documentation-review-skill.md` | Review project and architecture documentation quality, license notice coverage, and content-provenance evidence | ADRs, C4 Model, UML, OpenAPI, AsyncAPI, runbooks, documentation-as-code, SPDX, CycloneDX, GitHub dependency graph/SBOM, npm registry metadata, PyPI metadata, repository-local license and provenance files | Documentation frameworks, supply-chain evidence sources, package registries, and local governance artifacts |
| `twelve-factor-compliance-skill.md` | Review cloud-native 12-factor readiness | The Twelve-Factor App, cloud-native configuration, logging, process, disposability, environment parity practices | Official methodology and cloud-native practice |

## External Reference Register

Use these references as source anchors when strengthening or auditing the
configuration:

| Topic | Reference | Why It Is Used |
| --- | --- | --- |
| IBM Bob | [IBM Bob documentation](https://bob.ibm.com/docs) | Product context for Bob as an AI SDLC partner |
| IBM Bob introduction | [IBM Bob getting started introduction](https://bob.ibm.com/docs/ide/getting-started/tutorials/introduction) | Product-level lifecycle positioning |
| IBM Bob launch | [IBM announcement for Bob](https://newsroom.ibm.com/2026-04-28-introducing-ibm-bob-ai-development-partner-that-takes-enterprises-from-ai-assisted-coding-to-production-ready-software) | Public IBM positioning and production-ready SDLC framing |
| Spec-driven development | [IBM Think: Spec-driven development](https://www.ibm.com/think/topics/spec-driven-development) | SDD framing and AI-assisted development context |
| AI risk management | [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework) | Governance, risk, and trustworthiness framing for AI-assisted workflows |
| Generative AI risk profile | [NIST Generative AI Profile](https://www.nist.gov/itl/ai-risk-management-framework/generative-artificial-intelligence-profile) | Generative-AI-specific risk management and control considerations |
| LLM application risks | [OWASP Top 10 for Large Language Model Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/) | LLM, agent, prompt, data exposure, and generated-output risk baseline |
| Requirements engineering | [ISO/IEC/IEEE 29148:2018](https://www.iso.org/standard/72089.html) | Requirements engineering standard |
| Requirements practice | [IBM Requirements Management](https://www.ibm.com/think/topics/what-is-requirements-management) | Vendor guidance for requirements management |
| Requirements certification | [IREB CPRE](https://www.ireb.org/en/cpre/) | Requirements engineering professional body |
| Software engineering body of knowledge | [SWEBOK](https://www.computer.org/education/bodies-of-knowledge/software-engineering) | SDLC and software engineering knowledge-area framing |
| Security risks | [OWASP Top 10](https://owasp.org/www-project-top-ten/) | Web application security risk baseline |
| Security verification | [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) | Application security requirements and verification baseline |
| Threat modeling | [OWASP Threat Modeling](https://owasp.org/www-community/Threat_Modeling) and [OWASP Threat Modeling Process](https://owasp.org/www-community/Threat_Modeling_Process) | Threat modeling workflow and STRIDE references |
| Secure SDLC | [NIST SSDF](https://csrc.nist.gov/Projects/ssdf) | Secure software development practice baseline |
| Architecture communication | [C4 Model](https://c4model.com/) | Architecture diagram levels and communication model |
| Architecture documentation | [arc42](https://arc42.org/) | Architecture documentation structure |
| Architecture decisions | [Architecture Decision Records](https://adr.github.io/) | Lightweight architecture decision capture |
| Cloud-native operations | [The Twelve-Factor App](https://12factor.net/) | Cloud-native app methodology |
| GitHub issue automation | [GitHub REST issues API](https://docs.github.com/en/rest/issues/issues) | Issue creation and update behavior for scripts |
| GitHub dependency graph and SBOM export | [GitHub dependency graph SBOM export](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/exporting-a-software-bill-of-materials-for-your-repository) | Release and dependency evidence for repository license, dependency, and provenance reviews |
| SPDX | [SPDX specifications](https://spdx.dev/specifications/) | SBOM and license-expression evidence model for release and compliance documentation |
| CycloneDX | [CycloneDX specifications](https://cyclonedx.org/specification/overview/) | SBOM evidence model for dependency and supply-chain documentation |
| npm registry metadata | [npm package metadata and registry docs](https://docs.npmjs.com/about-packages-and-modules) | Runtime package version, license, and deprecation evidence for Node/npm dependencies |
| PyPI project metadata | [PyPI project metadata](https://docs.pypi.org/project_metadata/) | Runtime package version and license evidence for Python dependencies |
| GitHub MCP | [GitHub MCP server](https://github.com/github/github-mcp-server) | Maintained GitHub MCP reference for future migration |

## AI Integration and Usage Source Basis

AI Integration and Usage was added as an SDLC topic to make AI-assisted
development explicit instead of hiding it inside implementation or tooling
tasks. Use this topic when the workflow includes AI coding assistants, models,
agents, MCP servers, prompt assets, generated-code provenance, human review
checkpoints, data-use restrictions, or validation evidence for AI-assisted
outputs.

The topic is grounded in these source groups:

| Source Group | References | How It Informs the SDLC Topic |
| --- | --- | --- |
| IBM Bob and SDD product framing | IBM Bob documentation, IBM Bob introduction, IBM Bob launch announcement, IBM Think spec-driven development article | Positions AI assistance as lifecycle work that spans requirements, design, coding, validation, and production readiness. |
| AI governance and risk | NIST AI RMF, NIST Generative AI Profile | Provides the risk-management basis for guardrails, human oversight, data-use limits, and validation evidence. |
| LLM and agent application security | OWASP Top 10 for Large Language Model Applications, OWASP ASVS, OWASP Top 10 | Provides security-risk prompts for tool access, prompt injection, data leakage, excessive agency, insecure output handling, and supply-chain exposure. |
| Secure software development | NIST SSDF | Keeps AI-assisted implementation aligned with secure SDLC practices, review evidence, and provenance expectations. |
| Local traceability practice | Requirements Traceability skill, GitHub Issue Traceability skill, Markdown and code-entry conventions | Restricts traceability matrices to GitHub issues, Markdown documents, and code entries in this configuration. |

When adding AI-specific skill behavior, first check whether the existing SDD,
Documentation Review, Security & Threat Modeling, Requirements Traceability,
and Configuration Gap Detector skills cover the request. Introduce a new skill
only when the user needs repeatable work for model evaluation, AI governance,
prompt lifecycle management, agent safety, privacy engineering, or AI supply
chain compliance that cannot be handled by those existing skills.

## License and Provenance Evidence Source Basis

License and provenance review was added to Documentation Review so Bob can keep
release-facing documentation, modes, and skills aligned when repository license
or source-evidence files change.

| Source Group | References | How It Informs Modes and Skills |
| --- | --- | --- |
| Repository-local evidence | `LICENSE`, `LICENSE_DOCUMENTATION.md`, `THIRD_PARTY_NOTICES.md`, `CONTENT_PROVENANCE.md`, `Modes/SDD/documentation/RESOURCE_LICENSES.md`, this file | Defines the current repository license scope, dependency notices, artifact provenance, and mode/skill source boundaries. |
| Supply-chain evidence standards | SPDX specifications, CycloneDX specifications, GitHub dependency graph SBOM export | Provides evidence models for SBOM, license-expression, dependency, and release-readiness checks. |
| Package registry evidence | npm registry/package metadata, PyPI project metadata | Provides direct runtime package version, license, and deprecation evidence for packages referenced by Bob scripts and MCP configuration. |
| Bob configuration evidence | `Modes/SDD/specifiction-driven-development-mode.yaml`, `SKILLS/sdd-*/SKILL.md`, `SKILLS/sdd-*/README.md`, quick-start guides, `Modes/SDD/README.md` | Keeps user-facing mode and skill behavior synchronized with license/provenance review capabilities. |

## Source Trust and Maintenance Rules

| Source Type | Trust Level | Maintenance Rule |
| --- | --- | --- |
| Official standards and specifications | High | Verify exact version before compliance claims |
| Official product documentation | High | Recheck when tool behavior or configuration changes |
| Recognized framework documentation | Medium-High | Use for methodology, not legal or certification claims |
| Vendor or community articles | Medium | Use as supporting context only |
| AI-generated or AI-assisted text | Requires maintainer review | Keep in provenance register and validate against source artifacts |
| General model knowledge | Lowest | Use only when local and authoritative sources do not cover the task |

## License and Terms Boundary

The external references in this document are knowledge sources, not vendored
repository content. They do not change the Apache-2.0 license for repository
files unless material is copied, adapted, translated, or embedded. Before using
external source text beyond citation or short paraphrase, check
[`RESOURCE_LICENSES.md`](RESOURCE_LICENSES.md), update
[`../../CONTENT_PROVENANCE.md`](../../CONTENT_PROVENANCE.md), and preserve any
required attribution or notices.

## Review Findings

### Strengths

- The repository already records artifact provenance in
  `CONTENT_PROVENANCE.md`.
- The custom modes consistently instruct Bob to prefer local skills before
  external tools or general knowledge.
- The SDD and architecture-review areas include a discovery and gap analysis
  skill to clarify lifecycle intent before selecting a skill set.
- The GitHub MCP dependency is documented as a runtime dependency with a
  third-party notice.

### Gaps and Recommendations

| Gap | Impact | Recommendation |
| --- | --- | --- |
| Individual skill files do not all include explicit "Knowledge Sources" sections | Reviewers must infer sources from scattered docs | Keep this file as the central source map and link to it from skill inventories |
| Some framework names are conceptual references without exact version/date | Compliance interpretation may become stale | Verify exact versions before regulated or audit-facing use |
| External resource licenses were previously not mapped next to the mode resources | Reviewers could miss attribution, share-alike, or proprietary-standard boundaries | Use `RESOURCE_LICENSES.md` as the license and terms map for external mode resources |
| The diagram source may not visually show the discovery skill | Visual architecture may lag textual documentation | Update Draw.io and exported PNG when the visual inventory is refreshed |
| Runtime dependency knowledge is separate from mode knowledge | Reviewers need to check multiple docs | Keep `THIRD_PARTY_NOTICES.md` for dependency licenses and this file for conceptual knowledge |

## Maintainer Checklist for Future Modes or Skills

When adding or changing a mode or skill:

1. Add or update the artifact in `../custom_modes.yaml` or `../skills/`.
2. Record artifact provenance in `../../CONTENT_PROVENANCE.md` when the
   provenance category changes.
3. Add a row in the Mode Knowledge Map or Skill Knowledge Map.
4. Add any new authoritative references to the External Reference Register.
5. Add or update license and terms notes in `Modes/SDD/documentation/RESOURCE_LICENSES.md` for any new
   external resource.
6. Add or update the skill's `README.md` in `SKILLS/sdd-<name>/` and update `Modes/SDD/README.md`.
7. Run the Markdown link checker:

```bash
python3 Modes/SDD/scripts/check_markdown_links.py .
```
