# Third-Party Notices

This file preserves the upstream license texts required by third-party
material adapted into this repository. Each section identifies the
files affected, the upstream source, and the verbatim license text whose
notice-preservation clause obligates us to ship it alongside the
adapted content.

This notice is required by issue #338 (compliance — repo notices). The
project-wide copyright posture for *original* contributions lives in
[`NOTICE.md`](./NOTICE.md); the upstream terms in this file always take
precedence for the files they cover.

---

## 1. `agency-agents` (MIT)

**Upstream project:** AgentLand Contributors — `agency-agents`,
<https://github.com/msitarzewski/agency-agents>

**Files in this repository adapted from `agency-agents`:**

- `.squad/agents/danny/charter.md`
- `.squad/agents/livingston/charter.md`

These charters carry an inline HTML attribution comment at line 5
pointing back to the upstream project. The license below applies to the
adapted portions of those files.

### License (MIT)

```
MIT License

Copyright (c) 2025 AgentLand Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Adding new third-party material

When copying or adapting source/content from an external project into
this repository:

1. Confirm the upstream license permits redistribution and identify
   any notice-preservation clauses (MIT, Apache-2.0, BSD families all
   carry one).
2. Append a new section to this file with the upstream project name,
   the affected files, and the verbatim license text.
3. Add an inline attribution comment to each adapted file pointing
   back to the upstream source, mirroring the pattern in
   `.squad/agents/danny/charter.md:5`.
4. If the upstream license is Apache-2.0 or another license that
   requires shipping a `NOTICE`-style file alongside the binary,
   coordinate with the in-app acknowledgements work tracked under
   issue #237 so the runtime surface stays in sync with this
   source-tree surface.
