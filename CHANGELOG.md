# Changelog

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
