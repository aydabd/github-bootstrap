# Changelog

## [2.0.0](https://github.com/aydabd/github-bootstrap/compare/v1.15.0...v2.0.0) (2026-09-01)


### ⚠ BREAKING CHANGES

* Generated repositories no longer receive lint.yml or the lint status check. They receive the quality workflow and quality status check instead; existing repositories are not migrated automatically.

### Features

* add a 14-day release cooldown to the tooling updater ([#167](https://github.com/aydabd/github-bootstrap/issues/167)) ([f019069](https://github.com/aydabd/github-bootstrap/commit/f0190696ac59ac9c1f71a905d31e9c5ca85d3c43))
* add maintenance safety check ([#135](https://github.com/aydabd/github-bootstrap/issues/135)) ([9bf8d16](https://github.com/aydabd/github-bootstrap/commit/9bf8d168ba6888139aaf4061f6efe0675afff769))
* add personal GitHub App E2E bootstrap ([a95f0a7](https://github.com/aydabd/github-bootstrap/commit/a95f0a79b0a778e41334cf680e6cfb9681b38da3))
* approve eligible automation workflows ([#130](https://github.com/aydabd/github-bootstrap/issues/130)) ([d5569ba](https://github.com/aydabd/github-bootstrap/commit/d5569bacf345d4c86c47ee7374a8b69eb2cfdc72))
* archive generated E2E repositories ([#132](https://github.com/aydabd/github-bootstrap/issues/132)) ([1b8d77d](https://github.com/aydabd/github-bootstrap/commit/1b8d77d8262b422d18e40377c3098551c7936b69))
* **auth:** require scoped GitHub App tokens ([#98](https://github.com/aydabd/github-bootstrap/issues/98)) ([828f5c2](https://github.com/aydabd/github-bootstrap/commit/828f5c2666288a0df6e75c92ae92cc6c5b7d865a))
* classify tooling update risk ([#127](https://github.com/aydabd/github-bootstrap/issues/127)) ([0e6d84d](https://github.com/aydabd/github-bootstrap/commit/0e6d84d0ac2ef10643e45717e0938dc10e8dfab0))
* clean up archived E2E repositories ([#133](https://github.com/aydabd/github-bootstrap/issues/133)) ([fb5d274](https://github.com/aydabd/github-bootstrap/commit/fb5d274a567fe2bcf5f4c06568a9cc272aca39fb))
* enable Reviewer App maintenance auto-merge ([#136](https://github.com/aydabd/github-bootstrap/issues/136)) ([5fec5c3](https://github.com/aydabd/github-bootstrap/commit/5fec5c3bd9c514ea7db4bc675deaee8d04092442))
* gate automation on Copilot review ([#134](https://github.com/aydabd/github-bootstrap/issues/134)) ([960aff5](https://github.com/aydabd/github-bootstrap/commit/960aff5be319cfcaa5979197c4514a3f6fbdd554))
* migrate automation maintenance lifecycle ([#138](https://github.com/aydabd/github-bootstrap/issues/138)) ([e0b41e5](https://github.com/aydabd/github-bootstrap/commit/e0b41e5019007348c75ff3d5aeea2e32fe201a7c))
* split bootstrap quality into profiled reusable capabilities ([#85](https://github.com/aydabd/github-bootstrap/issues/85)) ([58f86e2](https://github.com/aydabd/github-bootstrap/commit/58f86e2b186f258203b61530730241993ff2b033))
* validate generated E2E head SHA ([#131](https://github.com/aydabd/github-bootstrap/issues/131)) ([e825a7c](https://github.com/aydabd/github-bootstrap/commit/e825a7ca7da1e8d7a082e2701e238a670cb57700))
* verify maintenance bot commits ([#126](https://github.com/aydabd/github-bootstrap/issues/126)) ([2f82d1f](https://github.com/aydabd/github-bootstrap/commit/2f82d1f6773d74aba85de44288f41c13e337749a))


### Bug Fixes

* align template maintenance app credentials ([#143](https://github.com/aydabd/github-bootstrap/issues/143)) ([37108c2](https://github.com/aydabd/github-bootstrap/commit/37108c22ea8fac6d28ed3452e5bb66223bba2c00))
* allow weekly workflow refs ([3781b40](https://github.com/aydabd/github-bootstrap/commit/3781b40dae9b3c61fd5ac82eec952b29d39db23c))
* authenticate Git operations with App user tokens ([#100](https://github.com/aydabd/github-bootstrap/issues/100)) ([bb7633c](https://github.com/aydabd/github-bootstrap/commit/bb7633cf0220925dda2167b1af6f2e46d08217f8))
* avoid /user API in weekly tooling workflow ([#108](https://github.com/aydabd/github-bootstrap/issues/108)) ([9b182be](https://github.com/aydabd/github-bootstrap/commit/9b182be7d565d6553a605aa77879acb8d4f32df8))
* bootstrap tooling branch with App Git transport ([#155](https://github.com/aydabd/github-bootstrap/issues/155)) ([06269a8](https://github.com/aydabd/github-bootstrap/commit/06269a8c0988b3b4f73039bd6f6891a6994d31fa))
* bootstrap weekly tooling refs from main ([#153](https://github.com/aydabd/github-bootstrap/issues/153)) ([83fe257](https://github.com/aydabd/github-bootstrap/commit/83fe2572df9110e42a8d973e928df8e1ecd4ccc6))
* bootstrap weekly tooling with workflow token ([#160](https://github.com/aydabd/github-bootstrap/issues/160)) ([3768a31](https://github.com/aydabd/github-bootstrap/commit/3768a3170fce5093190024abc4b4d164dd039271))
* create missing repository labels ([#145](https://github.com/aydabd/github-bootstrap/issues/145)) ([78a3cb8](https://github.com/aydabd/github-bootstrap/commit/78a3cb820e9cc0c783a01c2ffcb8074b1dda4c35))
* create tooling commits atomically ([#154](https://github.com/aydabd/github-bootstrap/issues/154)) ([001d75c](https://github.com/aydabd/github-bootstrap/commit/001d75c8652e01bf7d1c94a65acad3d40a5510e5))
* create weekly branch with writer app token ([#151](https://github.com/aydabd/github-bootstrap/issues/151)) ([b699304](https://github.com/aydabd/github-bootstrap/commit/b6993044eb232f71051c286054a8ae1257e6c001))
* create weekly tooling branch refs through API ([#152](https://github.com/aydabd/github-bootstrap/issues/152)) ([7f07299](https://github.com/aydabd/github-bootstrap/commit/7f07299430930017a08ba4474170ec9859930f7e))
* create weekly tooling branch through GraphQL ([#163](https://github.com/aydabd/github-bootstrap/issues/163)) ([a2808ce](https://github.com/aydabd/github-bootstrap/commit/a2808ce2cbf1f093147397a906fdb1a2df94a140))
* create weekly tooling pull requests through REST ([#148](https://github.com/aydabd/github-bootstrap/issues/148)) ([a051e25](https://github.com/aydabd/github-bootstrap/commit/a051e25e0c5f5c0f00d51d586500c9cab6fa775f))
* create weekly tooling refs through API ([7f07299](https://github.com/aydabd/github-bootstrap/commit/7f07299430930017a08ba4474170ec9859930f7e))
* create weekly tooling refs through the API ([#159](https://github.com/aydabd/github-bootstrap/issues/159)) ([18286b5](https://github.com/aydabd/github-bootstrap/commit/18286b54e521fe1a599ed40116350dc464cdf996))
* diagnose maintenance writer installation ([#157](https://github.com/aydabd/github-bootstrap/issues/157)) ([f00050f](https://github.com/aydabd/github-bootstrap/commit/f00050fe08631b00a4b34f5443570cce7314c623))
* grant maintenance-labeling token pull-request write ([#173](https://github.com/aydabd/github-bootstrap/issues/173)) ([7b1d44b](https://github.com/aydabd/github-bootstrap/commit/7b1d44bf29e6286c10e689de4d9c34f7523e33b9))
* grant weekly tooling workflow permission ([#161](https://github.com/aydabd/github-bootstrap/issues/161)) ([3781b40](https://github.com/aydabd/github-bootstrap/commit/3781b40dae9b3c61fd5ac82eec952b29d39db23c))
* guard weekly tooling run against mid-run main changes ([#166](https://github.com/aydabd/github-bootstrap/issues/166)) ([5a00787](https://github.com/aydabd/github-bootstrap/commit/5a007873441ba57327f07c2418fe5e2c1186557e))
* harden tooling metadata gates ([#129](https://github.com/aydabd/github-bootstrap/issues/129)) ([20e7823](https://github.com/aydabd/github-bootstrap/commit/20e78232f80c8210ac9a3c8ca21702e37d7a529f))
* initialize validation checkouts on main ([#142](https://github.com/aydabd/github-bootstrap/issues/142)) ([10bd637](https://github.com/aydabd/github-bootstrap/commit/10bd6375f61bf2087fcd79863906c9e474fd04f6))
* isolate GitHub App credentials by role ([#141](https://github.com/aydabd/github-bootstrap/issues/141)) ([d514583](https://github.com/aydabd/github-bootstrap/commit/d51458395d90e1e47d0bd6342efc95ae2e76bf3e))
* label maintenance pull requests through REST ([#147](https://github.com/aydabd/github-bootstrap/issues/147)) ([a2d7736](https://github.com/aydabd/github-bootstrap/commit/a2d7736d09f23404b75b4e21014d17d667394086))
* preserve GitHub token for weekly tooling auth ([#106](https://github.com/aydabd/github-bootstrap/issues/106)) ([808f0e9](https://github.com/aydabd/github-bootstrap/commit/808f0e93022a0bfa12d443b864002e0c0d4aacf9))
* remove deprecated GitHub App ID output ([#144](https://github.com/aydabd/github-bootstrap/issues/144)) ([05310bf](https://github.com/aydabd/github-bootstrap/commit/05310bf672ef72e092f640bd7974daacf3b42f20))
* run weekly tooling on schedule only ([#150](https://github.com/aydabd/github-bootstrap/issues/150)) ([29a11a7](https://github.com/aydabd/github-bootstrap/commit/29a11a7f8a58f4996a8af4e37f7764e09f1ea4da))
* satisfy shellcheck validation checks ([#101](https://github.com/aydabd/github-bootstrap/issues/101)) ([32bdcd3](https://github.com/aydabd/github-bootstrap/commit/32bdcd3e06460840ced353741200fc36d49bdca9))
* sign off weekly tooling update commits ([#111](https://github.com/aydabd/github-bootstrap/issues/111)) ([7d10a41](https://github.com/aydabd/github-bootstrap/commit/7d10a41531fd7d077e7dc781e7e5b244b26e0897))
* skip conda pre-release versions in tooling updater ([#165](https://github.com/aydabd/github-bootstrap/issues/165)) ([4dddb07](https://github.com/aydabd/github-bootstrap/commit/4dddb077ae0afd844c986a38ff2fbb204ea72e18))
* skip maintenance merge runs without pull requests ([#146](https://github.com/aydabd/github-bootstrap/issues/146)) ([290a398](https://github.com/aydabd/github-bootstrap/commit/290a39859bdf47ec4e3d9a5b2e095f26e1829882))
* skip maintenance safety without pull request ([#139](https://github.com/aydabd/github-bootstrap/issues/139)) ([c134865](https://github.com/aydabd/github-bootstrap/commit/c134865c173c927bd7e7979fe3f22cc1c66f98ef))
* submit GitHub App manifests with POST ([#140](https://github.com/aydabd/github-bootstrap/issues/140)) ([a099472](https://github.com/aydabd/github-bootstrap/commit/a09947205516885b50a91e8845c8ae110fbcce10))
* use app token for weekly refs ([698667b](https://github.com/aydabd/github-bootstrap/commit/698667bf258d05d814b4ad1aa23644ad514ed598))
* use App token for weekly refs ([#162](https://github.com/aydabd/github-bootstrap/issues/162)) ([698667b](https://github.com/aydabd/github-bootstrap/commit/698667bf258d05d814b4ad1aa23644ad514ed598))
* use github token for weekly tooling ([#107](https://github.com/aydabd/github-bootstrap/issues/107)) ([9096409](https://github.com/aydabd/github-bootstrap/commit/90964095fe4952b1d80d7b76397a9ad953b6c13e))
* verify weekly tooling branch creation ([#149](https://github.com/aydabd/github-bootstrap/issues/149)) ([15412a9](https://github.com/aydabd/github-bootstrap/commit/15412a9f241a5c820b70becc9981ef3aaa2a51ae))
* wait for weekly tooling branch visibility ([#158](https://github.com/aydabd/github-bootstrap/issues/158)) ([e02acb6](https://github.com/aydabd/github-bootstrap/commit/e02acb639e78e42af6a4a8431df1765abd9318a8))

## [1.15.0](https://github.com/aydabd/github-bootstrap/compare/v1.14.1...v1.15.0) (2026-08-17)


### Features

* add generic GitHub workflow skills and templates ([#83](https://github.com/aydabd/github-bootstrap/issues/83)) ([557cb15](https://github.com/aydabd/github-bootstrap/commit/557cb1554a4412eed2ddd0bd32ae9635fe56d669))


### Bug Fixes

* **docs:** fix lint issues in git-multi-account skill ([4b76807](https://github.com/aydabd/github-bootstrap/commit/4b76807cdb4d527982d620f9bda471737d4108a4))
* restore lint and address security review findings ([#75](https://github.com/aydabd/github-bootstrap/issues/75)) ([a7721ce](https://github.com/aydabd/github-bootstrap/commit/a7721ceddc6117ac58e5508a6d36239e07420b19))

## [1.14.1](https://github.com/aydabd/github-bootstrap/compare/v1.14.0...v1.14.1) (2026-07-21)


### Bug Fixes

* **release:** update release-please configuration ([d19a6da](https://github.com/aydabd/github-bootstrap/commit/d19a6da636238b61572851c3999a18edc1973189))
* use --no-verify on automation commit in weekly tooling update workflow ([#66](https://github.com/aydabd/github-bootstrap/issues/66)) ([fa95a58](https://github.com/aydabd/github-bootstrap/commit/fa95a58dd2c653af9d8a0f56ae148d2cd4de8558))

## [1.14.0](https://github.com/aydabd/github-bootstrap/compare/v1.13.0...v1.14.0) (2026-07-07)


### Features

* **existing-repo:** add modular setup workflows ([d88259f](https://github.com/aydabd/github-bootstrap/commit/d88259f287191cffa4109d8019f1a27474b65bc0))

## [1.13.0](https://github.com/aydabd/github-bootstrap/compare/v1.12.1...v1.13.0) (2026-07-06)


### Features

* add .editorconfig template file ([b598cf7](https://github.com/aydabd/github-bootstrap/commit/b598cf753f83ee93ae9f47308d970a8a9f813ddd))
* add AI code review with CodeRabbit and Claude ([#12](https://github.com/aydabd/github-bootstrap/issues/12)) ([96020be](https://github.com/aydabd/github-bootstrap/commit/96020be682c809ddc63b5a9889bcf02509f45a6e))
* add canonical agent instructions, skills, and templates ([452ed3b](https://github.com/aydabd/github-bootstrap/commit/452ed3b88e90a9f2e7be6aa73af4789bd5816e7f))
* add GHES support and fix terraform-create-repository parity ([7917fa8](https://github.com/aydabd/github-bootstrap/commit/7917fa8d398fbbd76b101abf20b2640897016164))
* add GitHub App-first reusable bootstrap workflows with PAT fallback ([f712aff](https://github.com/aydabd/github-bootstrap/commit/f712aff4a5d8744c3a249e108ca6497d4e06b09d))
* add GitHub App-first reusable bootstrap workflows with PAT fallback ([f712aff](https://github.com/aydabd/github-bootstrap/commit/f712aff4a5d8744c3a249e108ca6497d4e06b09d))
* add PR review agent kit and remove Super-Linter references ([1a7ec07](https://github.com/aydabd/github-bootstrap/commit/1a7ec0721235a4d134968d7449e482b9a3b40744))
* add super-linter badge with template placeholders ([2844ed5](https://github.com/aydabd/github-bootstrap/commit/2844ed553a36d150552f944e8b5c423bbff97801))
* add super-linter workflow and configuration for bootstrap repository ([1ab9a39](https://github.com/aydabd/github-bootstrap/commit/1ab9a3940cda948ee9beeef0101ad3ab06414915))
* add Terraform IaC alternative for GitHub repository bootstrapping ([#3](https://github.com/aydabd/github-bootstrap/issues/3)) ([17452de](https://github.com/aydabd/github-bootstrap/commit/17452ded19773709d45fbd75d1e80f5b6b051c89))
* add tri-mode env manager support ([#33](https://github.com/aydabd/github-bootstrap/issues/33)) ([bf82b09](https://github.com/aydabd/github-bootstrap/commit/bf82b09b01409ed89effaad155b2884cf2ed4d9f))
* **config:** use inclusion-only mode for super-linter ([a22c1a3](https://github.com/aydabd/github-bootstrap/commit/a22c1a361e450dcfeebac329967a2989150e7b5d))
* enhance release tooling with commitlint, super-linter, and options ([ddccc23](https://github.com/aydabd/github-bootstrap/commit/ddccc233aa6f2f339d749ca527330a0e65c5049a))
* harden bootstrap provider workflows ([bf82b09](https://github.com/aydabd/github-bootstrap/commit/bf82b09b01409ed89effaad155b2884cf2ed4d9f))
* improve make command visibility ([#39](https://github.com/aydabd/github-bootstrap/issues/39)) ([fc6356c](https://github.com/aydabd/github-bootstrap/commit/fc6356c30aeb89d83a54b55dc49307543b621ffe))
* **linters:** consolidate all configs in .github/linters ([01eb7bb](https://github.com/aydabd/github-bootstrap/commit/01eb7bb685acfd39b6ca559ed0c3b3300fa67eaf))
* modular bootstrapping with explicit case-based control flow ([#23](https://github.com/aydabd/github-bootstrap/issues/23)) ([82a650a](https://github.com/aydabd/github-bootstrap/commit/82a650ad5c6e2e9ea18f94a7406521ecd0a93818))
* security baseline, governance docs, CodeQL, and tightened branch rulesets ([#18](https://github.com/aydabd/github-bootstrap/issues/18)) ([2084d84](https://github.com/aydabd/github-bootstrap/commit/2084d84bfdb83f5360808db0d177ce9b5b8743ad))
* support user-supplied PAT via workflow input with composite token resolution ([1e72b07](https://github.com/aydabd/github-bootstrap/commit/1e72b072a2ce7e835c4a1885f240743d05a45285))
* **templates:** comprehensive language-specific linter support ([e2428ac](https://github.com/aydabd/github-bootstrap/commit/e2428ac507d4c5409820ef4f19aab6db2b58e12d))
* **test:** add API parity assertions for settings and rulesets ([c230e91](https://github.com/aydabd/github-bootstrap/commit/c230e9112833880eb9adc665c33ac8153de40782))
* **test:** complete Phase 3 workflow parity and preset scenarios ([#56](https://github.com/aydabd/github-bootstrap/issues/56)) ([622136e](https://github.com/aydabd/github-bootstrap/commit/622136e16276bbef043dd16a7570b69cfad172b1))
* **token-optimization:** add generated repo optimizer defaults ([#28](https://github.com/aydabd/github-bootstrap/issues/28)) ([cab1574](https://github.com/aydabd/github-bootstrap/commit/cab157478db403b1b119ed93c2c07f4cdce45198))
* **token-optimization:** add token optimization bootstrap templates ([cab1574](https://github.com/aydabd/github-bootstrap/commit/cab157478db403b1b119ed93c2c07f4cdce45198))
* **tools:** add bootstrap input normalizer package and CLI ([#51](https://github.com/aydabd/github-bootstrap/issues/51)) ([6c3b387](https://github.com/aydabd/github-bootstrap/commit/6c3b3871224f93745e523c37711f69bd8de07325))
* **tools:** add tooling updater to Go workspace module ([#40](https://github.com/aydabd/github-bootstrap/issues/40)) ([1a354d0](https://github.com/aydabd/github-bootstrap/commit/1a354d0da2058a584397214a298a2f42e50cf630))
* **tools:** decouple runtime/tool updater and extend runtime coverage ([#44](https://github.com/aydabd/github-bootstrap/issues/44)) ([213dd85](https://github.com/aydabd/github-bootstrap/commit/213dd852ab2326f4959b81710d82027ca2ca765d))
* **tools:** migrate precommit renderer to bootstrapinputs ([#52](https://github.com/aydabd/github-bootstrap/issues/52)) ([9e15803](https://github.com/aydabd/github-bootstrap/commit/9e15803d5bf45aee095e264665ffc4de0aa65342))
* **workflow:** add cleanup on failure and language-agnostic support ([e80b38e](https://github.com/aydabd/github-bootstrap/commit/e80b38e4e557ce02215c9ff0327f47d37d417a4a))
* **workflow:** replace sleep with active GitHub API polling ([9b5036f](https://github.com/aydabd/github-bootstrap/commit/9b5036fa0ed8ccedc317298403a21a73df0fbc40))
* **workflows:** consume bootstrap input normalizer outputs ([#53](https://github.com/aydabd/github-bootstrap/issues/53)) ([6ec6b24](https://github.com/aydabd/github-bootstrap/commit/6ec6b248f3f3c3f2d501a2d8b40e584648be95e5))
* **workflows:** extract codeql configuration action ([99e01e0](https://github.com/aydabd/github-bootstrap/commit/99e01e04939b2a292c9cad349a58e52087e3f9a2))
* **workflows:** extract composite actions (Phase 2) ([#54](https://github.com/aydabd/github-bootstrap/issues/54)) ([a644ee9](https://github.com/aydabd/github-bootstrap/commit/a644ee97c57758c4408b42663cd389db71ce3a24))
* **workflows:** modular pre-commit renderer for multi-language repos ([#47](https://github.com/aydabd/github-bootstrap/issues/47)) ([22fbf58](https://github.com/aydabd/github-bootstrap/commit/22fbf58bf15296a4a14c8b012dd0c3c76b2efec6))


### Bug Fixes

* add `indent_size = unset` for markdown in template `.editorconfig` ([#6](https://github.com/aydabd/github-bootstrap/issues/6)) ([7407f09](https://github.com/aydabd/github-bootstrap/commit/7407f09bea4861e3afb0ce31e1e19ccb20d02f64))
* add YAML document separator to template .pre-commit-config.yaml files ([4cd3f75](https://github.com/aydabd/github-bootstrap/commit/4cd3f750d95fbca32890d068fd5923ab95cd45dc))
* address remaining unresolved PR [#33](https://github.com/aydabd/github-bootstrap/issues/33) Copilot comments ([#35](https://github.com/aydabd/github-bootstrap/issues/35)) ([7976a74](https://github.com/aydabd/github-bootstrap/commit/7976a74ca85ecee4a5acda7af61e0b8202ccaf6a))
* align template super-linter workflow with bootstrap repo approach ([efc91cd](https://github.com/aydabd/github-bootstrap/commit/efc91cdf1948ac9e0da21a76cd50490348d87dee))
* **cache:** add cache dependency path at the tools module ([413c185](https://github.com/aydabd/github-bootstrap/commit/413c1858aa9ff563644afb4d4b1433b24d7c5263))
* **ci:** repair tooling updater fetch and refresh action/dependabot config ([61b7192](https://github.com/aydabd/github-bootstrap/commit/61b719251c2c659b1ddf59c44963aeb35cacb8ba))
* **ci:** require coderabbit status instead of code owner review ([6d34be8](https://github.com/aydabd/github-bootstrap/commit/6d34be8cbaf69ca6f985afe776f384d43d930624))
* **ci:** run gh pr comment without local git checkout ([f006f4b](https://github.com/aydabd/github-bootstrap/commit/f006f4ba47eed607127a422425ea9845c05f82e1))
* **ci:** tolerate missing optional automation label ([fd83405](https://github.com/aydabd/github-bootstrap/commit/fd83405a37112a9fdcf3cb421977059e5405ad1b))
* copy .claude/ and .windsurfrules to created repositories ([454cad3](https://github.com/aydabd/github-bootstrap/commit/454cad343f69420c56f6035c638fd1d36f9b24d2))
* **deps:** bump actions/cache from 5 to 6 ([#31](https://github.com/aydabd/github-bootstrap/issues/31)) ([4b98ee1](https://github.com/aydabd/github-bootstrap/commit/4b98ee1c462f761e20e230758f2330d4526d6cca))
* **deps:** bump actions/checkout from 6 to 7 ([#29](https://github.com/aydabd/github-bootstrap/issues/29)) ([33cbed4](https://github.com/aydabd/github-bootstrap/commit/33cbed49e01ffdccbc12f29b2920ee8969a7d569))
* **deps:** bump googleapis/release-please-action from 4.4.0 to 5.0.0 ([#21](https://github.com/aydabd/github-bootstrap/issues/21)) ([439221b](https://github.com/aydabd/github-bootstrap/commit/439221b7138ff0e01bd5b55b456d5c1f05034278))
* exclude CHANGELOG.md from markdownlint linting ([#8](https://github.com/aydabd/github-bootstrap/issues/8)) ([e06989a](https://github.com/aydabd/github-bootstrap/commit/e06989a6e4ff2d2bf3913d0926580f21bd2c0c24))
* **main:** clean up renderer dedup and workflow input handling ([2a0a1e4](https://github.com/aydabd/github-bootstrap/commit/2a0a1e4d35d5561c5df39ee392e9f48367b092fe))
* make mise bootstrap work without global PATH ([#37](https://github.com/aydabd/github-bootstrap/issues/37)) ([17bf103](https://github.com/aydabd/github-bootstrap/commit/17bf103b6508ed4ba7cc70046525e460fbf383b8))
* **mise:** make local bootstrap work without global PATH ([17bf103](https://github.com/aydabd/github-bootstrap/commit/17bf103b6508ed4ba7cc70046525e460fbf383b8))
* prevent cleanup from running when repo creation fails early ([121de41](https://github.com/aydabd/github-bootstrap/commit/121de413285836f50ccaf45e037b82fb91ca087d))
* **release:** trigger next patch release ([61e0d43](https://github.com/aydabd/github-bootstrap/commit/61e0d43f77ce5542bdac1a763abe376b2175e695))
* remove disallowed template expression from composite action input description ([#16](https://github.com/aydabd/github-bootstrap/issues/16)) ([a0a0d46](https://github.com/aydabd/github-bootstrap/commit/a0a0d467d0945c8245f80c873c3b9df9897a6a9e))
* remove Markdown from Prettier scope to resolve conflict with markdownlint ([b91c3bf](https://github.com/aydabd/github-bootstrap/commit/b91c3bfc859e6289379667fcdbd1dde42bedba6a))
* resolve editorconfig, markdown, and natural language linting errors ([64f66fb](https://github.com/aydabd/github-bootstrap/commit/64f66fba50e79db1307df2e8880b3d8f555eb3e9))
* resolve markdownlint and prettier errors ([109845e](https://github.com/aydabd/github-bootstrap/commit/109845ecf5d2b5484176f6795629d354f310acd9))
* resolve super-linter errors for editorconfig and env validation ([f1f0a90](https://github.com/aydabd/github-bootstrap/commit/f1f0a9042afe9e8f0bbc04efa36be3d5195f0d27))
* resolve super-linter validation conflict by dynamically setting environment variables ([eb6bcdc](https://github.com/aydabd/github-bootstrap/commit/eb6bcdc431c1839db343b141d5f9ebbace77825b))
* simplify super-linter workflow and use slim image ([f8635ba](https://github.com/aydabd/github-bootstrap/commit/f8635ba5cd3b94eb7475fe4b48f09ef273babd1c))
* **templates:** skip codeql when language sources are missing ([2a7131c](https://github.com/aydabd/github-bootstrap/commit/2a7131c9916da0fd213648373c28142e6f9c7196))
* **test-e2e:** accept default-branch selector in ruleset parity check ([86a0c32](https://github.com/aydabd/github-bootstrap/commit/86a0c322f6e6de8fbaaf1c257bf51418b0da8a7a))
* **test-e2e:** accept refs/heads selectors in ruleset target check ([07c9587](https://github.com/aydabd/github-bootstrap/commit/07c9587c0a08d404a6464c749ad3fa44e83da8c1))
* **test-e2e:** read full ruleset details by ID for parity checks ([644a309](https://github.com/aydabd/github-bootstrap/commit/644a309fa223ff511092d9c848eca89531a3544e))
* **test-workflow:** set setup-go cache dependency path ([6d0a7b7](https://github.com/aydabd/github-bootstrap/commit/6d0a7b76cefdb81e938be960ac9193d91dead39a))
* **test:** add repository creation baseline contract coverage ([#48](https://github.com/aydabd/github-bootstrap/issues/48)) ([9d437e8](https://github.com/aydabd/github-bootstrap/commit/9d437e88dc189100980b6fb59d9033211d1697ca))
* **test:** characterize workflow input validation ([#49](https://github.com/aydabd/github-bootstrap/issues/49)) ([d9760da](https://github.com/aydabd/github-bootstrap/commit/d9760daf0f4525f3db3a16f075e0cbc0315672f1))
* **test:** snapshot generated repository key files ([#50](https://github.com/aydabd/github-bootstrap/issues/50)) ([2f7cd69](https://github.com/aydabd/github-bootstrap/commit/2f7cd6955219110e20047355fc52db78d00a1213))
* update coderabbit reveiewer configs ([43a34d2](https://github.com/aydabd/github-bootstrap/commit/43a34d2249e1927f9e1b6689494ce18651fcbc42))
* update package-ecosystem from 'actions' to 'github-actions' ([29a6ecb](https://github.com/aydabd/github-bootstrap/commit/29a6ecb0187d48ed6aa39254a9676067540af584))
* update super-linter configuration and add testing workflow ([a2ea8a3](https://github.com/aydabd/github-bootstrap/commit/a2ea8a3a2176d5fc7a060bf0fa4f85a1bc81785c))
* use .editorconfig from linters folder ([836df82](https://github.com/aydabd/github-bootstrap/commit/836df826fb00cf5c01e540212911584f0254c95e))
* **workflows:** make test workflow polling ref-safe ([86f45d4](https://github.com/aydabd/github-bootstrap/commit/86f45d433fa510de05a4184dd984d44f0ecc80cb))
* **workflows:** remove template-only dirs from generated repositories ([#45](https://github.com/aydabd/github-bootstrap/issues/45)) ([31f86a0](https://github.com/aydabd/github-bootstrap/commit/31f86a07255d185e4320bc5e25bfcdefc71fa3fe))
* **workflows:** resolve unresolved PR33 provider bootstrap comments ([7976a74](https://github.com/aydabd/github-bootstrap/commit/7976a74ca85ecee4a5acda7af61e0b8202ccaf6a))

## [1.12.1](https://github.com/aydabd/github-bootstrap/compare/v1.12.0...v1.12.1) (2026-07-06)


### Bug Fixes

* **ci:** require coderabbit status instead of code owner review ([6d34be8](https://github.com/aydabd/github-bootstrap/commit/6d34be8cbaf69ca6f985afe776f384d43d930624))

## [1.12.0](https://github.com/aydabd/github-bootstrap/compare/v1.11.0...v1.12.0) (2026-07-06)


### Features

* **test:** add API parity assertions for settings and rulesets ([c230e91](https://github.com/aydabd/github-bootstrap/commit/c230e9112833880eb9adc665c33ac8153de40782))
* **test:** complete Phase 3 workflow parity and preset scenarios ([#56](https://github.com/aydabd/github-bootstrap/issues/56)) ([622136e](https://github.com/aydabd/github-bootstrap/commit/622136e16276bbef043dd16a7570b69cfad172b1))
* **tools:** add bootstrap input normalizer package and CLI ([#51](https://github.com/aydabd/github-bootstrap/issues/51)) ([6c3b387](https://github.com/aydabd/github-bootstrap/commit/6c3b3871224f93745e523c37711f69bd8de07325))
* **tools:** migrate precommit renderer to bootstrapinputs ([#52](https://github.com/aydabd/github-bootstrap/issues/52)) ([9e15803](https://github.com/aydabd/github-bootstrap/commit/9e15803d5bf45aee095e264665ffc4de0aa65342))
* **workflows:** consume bootstrap input normalizer outputs ([#53](https://github.com/aydabd/github-bootstrap/issues/53)) ([6ec6b24](https://github.com/aydabd/github-bootstrap/commit/6ec6b248f3f3c3f2d501a2d8b40e584648be95e5))
* **workflows:** extract codeql configuration action ([99e01e0](https://github.com/aydabd/github-bootstrap/commit/99e01e04939b2a292c9cad349a58e52087e3f9a2))
* **workflows:** extract composite actions (Phase 2) ([#54](https://github.com/aydabd/github-bootstrap/issues/54)) ([a644ee9](https://github.com/aydabd/github-bootstrap/commit/a644ee97c57758c4408b42663cd389db71ce3a24))
* **workflows:** modular pre-commit renderer for multi-language repos ([#47](https://github.com/aydabd/github-bootstrap/issues/47)) ([22fbf58](https://github.com/aydabd/github-bootstrap/commit/22fbf58bf15296a4a14c8b012dd0c3c76b2efec6))


### Bug Fixes

* **cache:** add cache dependency path at the tools module ([413c185](https://github.com/aydabd/github-bootstrap/commit/413c1858aa9ff563644afb4d4b1433b24d7c5263))
* **main:** clean up renderer dedup and workflow input handling ([2a0a1e4](https://github.com/aydabd/github-bootstrap/commit/2a0a1e4d35d5561c5df39ee392e9f48367b092fe))
* **test-e2e:** accept default-branch selector in ruleset parity check ([86a0c32](https://github.com/aydabd/github-bootstrap/commit/86a0c322f6e6de8fbaaf1c257bf51418b0da8a7a))
* **test-e2e:** accept refs/heads selectors in ruleset target check ([07c9587](https://github.com/aydabd/github-bootstrap/commit/07c9587c0a08d404a6464c749ad3fa44e83da8c1))
* **test-e2e:** read full ruleset details by ID for parity checks ([644a309](https://github.com/aydabd/github-bootstrap/commit/644a309fa223ff511092d9c848eca89531a3544e))
* **test-workflow:** set setup-go cache dependency path ([6d0a7b7](https://github.com/aydabd/github-bootstrap/commit/6d0a7b76cefdb81e938be960ac9193d91dead39a))
* **test:** add repository creation baseline contract coverage ([#48](https://github.com/aydabd/github-bootstrap/issues/48)) ([9d437e8](https://github.com/aydabd/github-bootstrap/commit/9d437e88dc189100980b6fb59d9033211d1697ca))
* **test:** characterize workflow input validation ([#49](https://github.com/aydabd/github-bootstrap/issues/49)) ([d9760da](https://github.com/aydabd/github-bootstrap/commit/d9760daf0f4525f3db3a16f075e0cbc0315672f1))
* **test:** snapshot generated repository key files ([#50](https://github.com/aydabd/github-bootstrap/issues/50)) ([2f7cd69](https://github.com/aydabd/github-bootstrap/commit/2f7cd6955219110e20047355fc52db78d00a1213))
* **workflows:** make test workflow polling ref-safe ([86f45d4](https://github.com/aydabd/github-bootstrap/commit/86f45d433fa510de05a4184dd984d44f0ecc80cb))
* **workflows:** remove template-only dirs from generated repositories ([#45](https://github.com/aydabd/github-bootstrap/issues/45)) ([31f86a0](https://github.com/aydabd/github-bootstrap/commit/31f86a07255d185e4320bc5e25bfcdefc71fa3fe))

## [1.11.0](https://github.com/aydabd/github-bootstrap/compare/v1.10.0...v1.11.0) (2026-07-04)


### Features

* **tools:** decouple runtime/tool updater and extend runtime coverage ([#44](https://github.com/aydabd/github-bootstrap/issues/44)) ([213dd85](https://github.com/aydabd/github-bootstrap/commit/213dd852ab2326f4959b81710d82027ca2ca765d))


### Bug Fixes

* **ci:** repair tooling updater fetch and refresh action/dependabot config ([61b7192](https://github.com/aydabd/github-bootstrap/commit/61b719251c2c659b1ddf59c44963aeb35cacb8ba))
* **ci:** run gh pr comment without local git checkout ([f006f4b](https://github.com/aydabd/github-bootstrap/commit/f006f4ba47eed607127a422425ea9845c05f82e1))
* **ci:** tolerate missing optional automation label ([fd83405](https://github.com/aydabd/github-bootstrap/commit/fd83405a37112a9fdcf3cb421977059e5405ad1b))

## [1.10.0](https://github.com/aydabd/github-bootstrap/compare/v1.9.1...v1.10.0) (2026-07-03)


### Features

* improve make command visibility ([#39](https://github.com/aydabd/github-bootstrap/issues/39)) ([fc6356c](https://github.com/aydabd/github-bootstrap/commit/fc6356c30aeb89d83a54b55dc49307543b621ffe))
* **tools:** add tooling updater to Go workspace module ([#40](https://github.com/aydabd/github-bootstrap/issues/40)) ([1a354d0](https://github.com/aydabd/github-bootstrap/commit/1a354d0da2058a584397214a298a2f42e50cf630))


### Bug Fixes

* make mise bootstrap work without global PATH ([#37](https://github.com/aydabd/github-bootstrap/issues/37)) ([17bf103](https://github.com/aydabd/github-bootstrap/commit/17bf103b6508ed4ba7cc70046525e460fbf383b8))
* **mise:** make local bootstrap work without global PATH ([17bf103](https://github.com/aydabd/github-bootstrap/commit/17bf103b6508ed4ba7cc70046525e460fbf383b8))

## [1.9.1](https://github.com/aydabd/github-bootstrap/compare/v1.9.0...v1.9.1) (2026-07-03)


### Bug Fixes

* address remaining unresolved PR [#33](https://github.com/aydabd/github-bootstrap/issues/33) Copilot comments ([#35](https://github.com/aydabd/github-bootstrap/issues/35)) ([7976a74](https://github.com/aydabd/github-bootstrap/commit/7976a74ca85ecee4a5acda7af61e0b8202ccaf6a))
* **workflows:** resolve unresolved PR33 provider bootstrap comments ([7976a74](https://github.com/aydabd/github-bootstrap/commit/7976a74ca85ecee4a5acda7af61e0b8202ccaf6a))

## [1.9.0](https://github.com/aydabd/github-bootstrap/compare/v1.8.0...v1.9.0) (2026-07-03)


### Features

* add tri-mode env manager support ([#33](https://github.com/aydabd/github-bootstrap/issues/33)) ([bf82b09](https://github.com/aydabd/github-bootstrap/commit/bf82b09b01409ed89effaad155b2884cf2ed4d9f))
* harden bootstrap provider workflows ([bf82b09](https://github.com/aydabd/github-bootstrap/commit/bf82b09b01409ed89effaad155b2884cf2ed4d9f))

## [1.8.0](https://github.com/aydabd/github-bootstrap/compare/v1.7.1...v1.8.0) (2026-07-02)


### Features

* **token-optimization:** add generated repo optimizer defaults ([#28](https://github.com/aydabd/github-bootstrap/issues/28)) ([cab1574](https://github.com/aydabd/github-bootstrap/commit/cab157478db403b1b119ed93c2c07f4cdce45198))
* **token-optimization:** add token optimization bootstrap templates ([cab1574](https://github.com/aydabd/github-bootstrap/commit/cab157478db403b1b119ed93c2c07f4cdce45198))


### Bug Fixes

* **deps:** bump actions/cache from 5 to 6 ([#31](https://github.com/aydabd/github-bootstrap/issues/31)) ([4b98ee1](https://github.com/aydabd/github-bootstrap/commit/4b98ee1c462f761e20e230758f2330d4526d6cca))

## [1.7.1](https://github.com/aydabd/github-bootstrap/compare/v1.7.0...v1.7.1) (2026-06-28)


### Bug Fixes

* **deps:** bump actions/checkout from 6 to 7 ([#29](https://github.com/aydabd/github-bootstrap/issues/29)) ([33cbed4](https://github.com/aydabd/github-bootstrap/commit/33cbed49e01ffdccbc12f29b2920ee8969a7d569))

## [1.7.0](https://github.com/aydabd/github-bootstrap/compare/v1.6.0...v1.7.0) (2026-05-25)


### Features

* add GitHub App-first reusable bootstrap workflows with PAT fallback ([f712aff](https://github.com/aydabd/github-bootstrap/commit/f712aff4a5d8744c3a249e108ca6497d4e06b09d))
* add GitHub App-first reusable bootstrap workflows with PAT fallback ([f712aff](https://github.com/aydabd/github-bootstrap/commit/f712aff4a5d8744c3a249e108ca6497d4e06b09d))

## [1.6.0](https://github.com/aydabd/github-bootstrap/compare/v1.5.0...v1.6.0) (2026-05-09)


### Features

* add GHES support and fix terraform-create-repository parity ([7917fa8](https://github.com/aydabd/github-bootstrap/commit/7917fa8d398fbbd76b101abf20b2640897016164))

## [1.5.0](https://github.com/aydabd/github-bootstrap/compare/v1.4.0...v1.5.0) (2026-05-09)


### Features

* modular bootstrapping with explicit case-based control flow ([#23](https://github.com/aydabd/github-bootstrap/issues/23)) ([82a650a](https://github.com/aydabd/github-bootstrap/commit/82a650ad5c6e2e9ea18f94a7406521ecd0a93818))

## [1.4.0](https://github.com/aydabd/github-bootstrap/compare/v1.3.1...v1.4.0) (2026-05-01)


### Features

* add PR review agent kit and remove Super-Linter references ([1a7ec07](https://github.com/aydabd/github-bootstrap/commit/1a7ec0721235a4d134968d7449e482b9a3b40744))


### Bug Fixes

* copy .claude/ and .windsurfrules to created repositories ([454cad3](https://github.com/aydabd/github-bootstrap/commit/454cad343f69420c56f6035c638fd1d36f9b24d2))
* **deps:** bump googleapis/release-please-action from 4.4.0 to 5.0.0 ([#21](https://github.com/aydabd/github-bootstrap/issues/21)) ([439221b](https://github.com/aydabd/github-bootstrap/commit/439221b7138ff0e01bd5b55b456d5c1f05034278))

## [1.3.1](https://github.com/aydabd/github-bootstrap/compare/v1.3.0...v1.3.1) (2026-05-01)


### Bug Fixes

* add YAML document separator to template .pre-commit-config.yaml files ([4cd3f75](https://github.com/aydabd/github-bootstrap/commit/4cd3f750d95fbca32890d068fd5923ab95cd45dc))
* **templates:** skip codeql when language sources are missing ([2a7131c](https://github.com/aydabd/github-bootstrap/commit/2a7131c9916da0fd213648373c28142e6f9c7196))
* update coderabbit reveiewer configs ([43a34d2](https://github.com/aydabd/github-bootstrap/commit/43a34d2249e1927f9e1b6689494ce18651fcbc42))
* update package-ecosystem from 'actions' to 'github-actions' ([29a6ecb](https://github.com/aydabd/github-bootstrap/commit/29a6ecb0187d48ed6aa39254a9676067540af584))

## [1.3.0](https://github.com/aydabd/github-bootstrap/compare/v1.2.1...v1.3.0) (2026-04-20)


### Features

* security baseline, governance docs, CodeQL, and tightened branch rulesets ([#18](https://github.com/aydabd/github-bootstrap/issues/18)) ([2084d84](https://github.com/aydabd/github-bootstrap/commit/2084d84bfdb83f5360808db0d177ce9b5b8743ad))

## [1.2.1](https://github.com/aydabd/github-bootstrap/compare/v1.2.0...v1.2.1) (2026-03-12)

### Bug Fixes

- remove disallowed template expression from composite action input description ([#16](https://github.com/aydabd/github-bootstrap/issues/16)) ([a0a0d46](https://github.com/aydabd/github-bootstrap/commit/a0a0d467d0945c8245f80c873c3b9df9897a6a9e))

## [1.2.0](https://github.com/aydabd/github-bootstrap/compare/v1.1.0...v1.2.0) (2026-03-11)

### Features

- support user-supplied PAT via workflow input with composite token resolution ([1e72b07](https://github.com/aydabd/github-bootstrap/commit/1e72b072a2ce7e835c4a1885f240743d05a45285))

## [1.1.0](https://github.com/aydabd/github-bootstrap/compare/v1.0.2...v1.1.0) (2026-03-11)

### Features

- add AI code review with CodeRabbit and Claude ([#12](https://github.com/aydabd/github-bootstrap/issues/12)) ([96020be](https://github.com/aydabd/github-bootstrap/commit/96020be682c809ddc63b5a9889bcf02509f45a6e))

## [1.0.2](https://github.com/aydabd/github-bootstrap/compare/v1.0.1...v1.0.2) (2026-03-11)

### Bug Fixes

- remove Markdown from Prettier scope to resolve conflict with markdownlint ([b91c3bf](https://github.com/aydabd/github-bootstrap/commit/b91c3bfc859e6289379667fcdbd1dde42bedba6a))

## [1.0.1](https://github.com/aydabd/github-bootstrap/compare/v1.0.0...v1.0.1) (2026-03-11)

### Bug Fixes

- exclude CHANGELOG.md from markdownlint linting ([#8](https://github.com/aydabd/github-bootstrap/issues/8)) ([e06989a](https://github.com/aydabd/github-bootstrap/commit/e06989a6e4ff2d2bf3913d0926580f21bd2c0c24))

## 1.0.0 (2026-03-11)

### Features

- add .editorconfig template file ([b598cf7](https://github.com/aydabd/github-bootstrap/commit/b598cf753f83ee93ae9f47308d970a8a9f813ddd))
- add canonical agent instructions, skills, and templates ([452ed3b](https://github.com/aydabd/github-bootstrap/commit/452ed3b88e90a9f2e7be6aa73af4789bd5816e7f))
- add super-linter badge with template placeholders ([2844ed5](https://github.com/aydabd/github-bootstrap/commit/2844ed553a36d150552f944e8b5c423bbff97801))
- add super-linter workflow and configuration for bootstrap repository ([1ab9a39](https://github.com/aydabd/github-bootstrap/commit/1ab9a3940cda948ee9beeef0101ad3ab06414915))
- add Terraform IaC alternative for GitHub repository bootstrapping ([#3](https://github.com/aydabd/github-bootstrap/issues/3)) ([17452de](https://github.com/aydabd/github-bootstrap/commit/17452ded19773709d45fbd75d1e80f5b6b051c89))
- **config:** use inclusion-only mode for super-linter ([a22c1a3](https://github.com/aydabd/github-bootstrap/commit/a22c1a361e450dcfeebac329967a2989150e7b5d))
- enhance release tooling with commitlint, super-linter, and options ([ddccc23](https://github.com/aydabd/github-bootstrap/commit/ddccc233aa6f2f339d749ca527330a0e65c5049a))
- **linters:** consolidate all configs in .github/linters ([01eb7bb](https://github.com/aydabd/github-bootstrap/commit/01eb7bb685acfd39b6ca559ed0c3b3300fa67eaf))
- **templates:** comprehensive language-specific linter support ([e2428ac](https://github.com/aydabd/github-bootstrap/commit/e2428ac507d4c5409820ef4f19aab6db2b58e12d))
- **workflow:** add cleanup on failure and language-agnostic support ([e80b38e](https://github.com/aydabd/github-bootstrap/commit/e80b38e4e557ce02215c9ff0327f47d37d417a4a))
- **workflow:** replace sleep with active GitHub API polling ([9b5036f](https://github.com/aydabd/github-bootstrap/commit/9b5036fa0ed8ccedc317298403a21a73df0fbc40))

### Bug Fixes

- add `indent_size = unset` for markdown in template `.editorconfig` ([#6](https://github.com/aydabd/github-bootstrap/issues/6)) ([7407f09](https://github.com/aydabd/github-bootstrap/commit/7407f09bea4861e3afb0ce31e1e19ccb20d02f64))
- align template super-linter workflow with bootstrap repo approach ([efc91cd](https://github.com/aydabd/github-bootstrap/commit/efc91cdf1948ac9e0da21a76cd50490348d87dee))
- prevent cleanup from running when repo creation fails early ([121de41](https://github.com/aydabd/github-bootstrap/commit/121de413285836f50ccaf45e037b82fb91ca087d))
- resolve editorconfig, markdown, and natural language linting errors ([64f66fb](https://github.com/aydabd/github-bootstrap/commit/64f66fba50e79db1307df2e8880b3d8f555eb3e9))
- resolve markdownlint and prettier errors ([109845e](https://github.com/aydabd/github-bootstrap/commit/109845ecf5d2b5484176f6795629d354f310acd9))
- resolve super-linter errors for editorconfig and env validation ([f1f0a90](https://github.com/aydabd/github-bootstrap/commit/f1f0a9042afe9e8f0bbc04efa36be3d5195f0d27))
- resolve super-linter validation conflict by dynamically setting environment variables ([eb6bcdc](https://github.com/aydabd/github-bootstrap/commit/eb6bcdc431c1839db343b141d5f9ebbace77825b))
- simplify super-linter workflow and use slim image ([f8635ba](https://github.com/aydabd/github-bootstrap/commit/f8635ba5cd3b94eb7475fe4b48f09ef273babd1c))
- update super-linter configuration and add testing workflow ([a2ea8a3](https://github.com/aydabd/github-bootstrap/commit/a2ea8a3a2176d5fc7a060bf0fa4f85a1bc81785c))
- use .editorconfig from linters folder ([836df82](https://github.com/aydabd/github-bootstrap/commit/836df826fb00cf5c01e540212911584f0254c95e))
