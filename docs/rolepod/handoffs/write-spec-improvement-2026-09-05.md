# Write-spec improvement handoff

วันที่: 2026-09-05 · Audience: session ถัดไปที่พัฒนา Rolepod

สถานะ: **เอกสารส่งต่องาน — ยังไม่ได้แก้ skill หรือทดสอบพฤติกรรมของเวอร์ชันใหม่**

- Repository: `/Users/nuttaruj/Project/rolepod`
- Rolepod baseline: `354e020` · v2.79.0
- Matt Pocock reference snapshot: `3cca18b368ae95cdbdebbff572ccafa662551015`

## 1. เป้าหมายและขอบเขตการอนุมัติ

ปรับ `write-spec` ให้เปลี่ยนโจทย์เป็น spec ที่ตรงเจตนาผู้ใช้ ตรวจสอบได้ และส่งให้ `write-plan` ทำต่อโดยไม่เดาเรื่องสำคัญ พร้อมลดคำถามซ้ำ งานเอกสาร และการอนุมัติที่ไม่ได้เพิ่มข้อมูล

ข้อความที่ผู้ใช้ยืนยันในบทสนทนา:

> งั้นเราควรไม่จำกัดเหมือนกันไหมเพราะว่า แต่ละงานอย่างน้อย spec ที่ชัดที่สุดเพื่อให้ plan ตรงตามเป้าหมายที่สุด

> โอเคงั้นสรุปเรื่องการแก้ไข write-spec ให้หน่อย ให้ของเราทำงานได้เทียบเท่าหรือดีกว่าของ Matt ทุกมิติแบบไม่ over engineer ถามพร่ำเพื่อ ขอแบบละเอียดเป็น .md handoff เพื่อที่จะเอาไปให้ session ปรับปรุงพัฒนาต่อ

**ข้อสรุปที่ตกลงแล้ว:** เลิกใช้จำนวนคำถามเป็นเกณฑ์ความครบ ถามจนปิดประเด็นที่มีผลต่อ scope/behavior/plan ได้ โดยไม่ถามเรื่องที่รู้แล้วหรือค้นเองได้

**รายละเอียดด้านล่างเป็นข้อเสนอ implementation ของ handoff นี้** เช่น รูปแบบ compact contract และ placeholder marker ไม่ใช่ข้ออ้างว่าผู้ใช้ได้อนุมัติรายละเอียดทุกบรรทัดแล้ว Session ถัดไปใช้เป็นฐานทำงานและตัดสินใจเรื่อง reversible ตามคำสั่งที่ได้รับ ไม่ต้องกลับไปสัมภาษณ์เรื่องที่ตกลงแล้ว

งานรอบที่สร้างเอกสารนี้ครอบคลุมเฉพาะ handoff ไม่มีการแก้ production skill, install, commit, push หรือ release การส่งไฟล์นี้ให้ session ถัดไปต้องมาพร้อมคำสั่งให้ดำเนินการ เช่น kickoff ใน §15

### ความหมายของ “เทียบเท่าหรือดีกว่าทุกมิติ”

ใช้เป็นเป้าหมายของมิติใน §3 ไม่ใช่คำรับประกันว่า framework หนึ่งจะชนะทุกโมเดล ทุกโจทย์ และทุก budget มีสองระดับที่ต้องรายงานแยกกัน:

1. **ความสามารถของ protocol:** ครอบคลุมการถาม การค้น การบันทึก การพิสูจน์ และการส่งต่อ โดยไม่มีคำสั่งขัดกัน
2. **ผลการใช้งาน:** ทดสอบบทสนทนาจริง/หลาย turn ด้วยโจทย์และโมเดลที่เทียบกันได้ แล้วรายงานคุณภาพ เวลา และต้นทุน

ห้ามใช้จำนวน skills, ความยาวเอกสาร, gate ที่มากกว่า หรือ structural tests ที่ผ่าน เป็นหลักฐานว่าฉลาดกว่า/เร็วกว่า/ประหยัดกว่า

## 2. Baseline ที่ตรวจแล้ว

ตรวจ source ปัจจุบัน, installed `write-spec` ทั้ง 6 ไฟล์, บทความ AI Hero ทั้ง 6 หน้า และ source ที่ skill เหล่านั้นเรียกใช้ พบว่า installed `write-spec` ตรงกับ source ณ baseline นี้

| ID | สิ่งที่พบ | หลักฐานและข้อจำกัด |
|---|---|---|
| F1 | Skill หลักถามแบบ frontier แต่จำกัดประมาณ 5 ข้อต่อรอบ | [SKILL.md:83](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/SKILL.md:83) |
| F2 | Question bank ยังสั่งถามทีละข้อ | [question-bank.md:5](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/references/question-bank.md:5) ขัดกับ F1 |
| F3 | มี hard stop เมื่อ goal ยังไม่ชัดหลัง 5 คำถาม | [SKILL.md:174](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/SKILL.md:174) เป็นคนละกฎกับเพดานต่อรอบ |
| F4 | One-session ที่เข้า write-spec ยังกรอก template ครบ 11 ส่วนและเขียน scratch file เพื่อ lint | [SKILL.md:117](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/SKILL.md:117) แต่ R0–R2 มีเส้นทางลดขั้นตอนอยู่แล้ว ห้ามเหมารวมว่าทุกงานเสียต้นทุนนี้ |
| F5 | เกณฑ์สำเร็จต้องมี `proven by`; มี Gate 1 และ Gate 2 สำหรับ file mode | [template:25](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/templates/spec-template.md:25), [SKILL.md:113](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/SKILL.md:113) เป็นข้อกำหนดให้ agent ปฏิบัติ ไม่ใช่หลักฐานว่าทุก session ทำจริง |
| F6 | มี decision map, prototype และ scope splitting แล้ว | [chart-work.md](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/references/chart-work.md), [scope-splitting.md](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/references/scope-splitting.md) ไม่ต้องเพิ่ม skill เลียนแบบอีกชุด |
| F7 | Cross-family critique มีอยู่แล้ว เป็น opt-in และจำกัดผล ≤5 items | [question-bank.md:54](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/references/question-bank.md:54) ขีดจำกัดผล critic ไม่ใช่ขีดจำกัด discovery ทั้งหมด |
| F8 | มี vertical slices และ requirement → task trace ใน write-plan | [write-plan:70](/Users/nuttaruj/Project/rolepod/core/skills/write-plan/SKILL.md:70), [write-plan:102](/Users/nuttaruj/Project/rolepod/core/skills/write-plan/SKILL.md:102) ไม่ควรย้ายการแตก implementation tickets มา Define |
| F9 | ชุดตรวจที่เกี่ยวข้องเป็น placeholder lint และ structural wiring | [spec-lint.sh](/Users/nuttaruj/Project/rolepod/tests/integration/cases/spec-lint.sh), [feature-from-spec.sh](/Users/nuttaruj/Project/rolepod/tests/integration/cases/feature-from-spec.sh), [Makefile:9](/Users/nuttaruj/Project/rolepod/Makefile:9) ยังไม่มีผล controlled comparison |

### หลักฐานที่รันแล้วในบทสนทนานี้

รันบน source baseline `354e020`:

```bash
bash tests/integration/cases/spec-lint.sh
bash tests/integration/cases/feature-from-spec.sh
```

ทั้งสองคำสั่ง exit 0; ผลท้ายคือ `spec-lint: pass` และ `feature-from-spec: pass` ไม่ได้รัน full suite เพื่อสรุป audit นี้

ทดสอบ regex ปัจจุบัน `<[^>]+>|TODO|TBD` เพิ่มเติมผ่าน stdin ของ `grep -niE`:

| Input probe | grep exit | ความหมาย |
|---|---:|---|
| Success criterion ว่า “Export works well.” ไม่มีวิธีพิสูจน์ | 1 | ไม่พบ marker จึงผ่าน placeholder lint |
| Desired behavior อนุญาต guest แต่ Constraints ห้าม guest | 1 | ความขัดแย้งทางความหมายยังผ่าน |
| Requirement ให้ render title ด้วย `<h1>` | 0 | HTML ปกติถูกจับเป็น placeholder |

สองกรณีแรกเกินหน้าที่ที่ placeholder lint ประกาศไว้ จึงเป็นข้อจำกัดของหลักฐาน ไม่ใช่ข้อพิสูจน์ว่า regex ผิด ส่วนกรณี HTML เป็น false positive จริง อย่าแก้ด้วย semantic parser ขนาดใหญ่

## 3. เทียบขอบเขตกับ Matt อย่างเป็นธรรม

Source links แบบ pin commit อยู่ใน §16 บทความเป็นคำอธิบายการใช้ ส่วน source เป็นข้อกำหนดที่ตรวจได้ ไม่ยกระดับรายงาน bug ในบทความให้เป็น defect ที่เราพิสูจน์เอง

| มิติ | Matt reference | Rolepod ปัจจุบัน | เป้าหมายหลังปรับ |
|---|---|---|---|
| ถามตาม dependency | [grilling](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/productivity/grilling/SKILL.md): ทุกข้อที่พร้อมตอบ ไม่มีเพดานตัวเลข | Frontier + ประมาณ 5 ต่อรอบ + reference ขัดกัน | Frontier เดียว ไม่มี arbitrary cap และไม่มีคำถามที่เดาคำตอบตั้งต้น |
| ลดคำถามไร้ประโยชน์ | [grilling](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/productivity/grilling/SKILL.md): ค้น facts เองและรอผู้ใช้ตัดสินใจ | มีหลักนี้แล้ว | เพิ่มกติกา skip/คำตอบบางส่วน/เปลี่ยนใจให้ไม่ถามซ้ำ |
| ศัพท์และความเข้าใจร่วม | grill-with-docs เรียก [domain-modeling](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/domain-modeling/SKILL.md) | ตรวจ repo และ ADR แล้ว แต่ศัพท์ไม่ได้เป็น protocol ชัดเจน | จับศัพท์กำกวมที่เปลี่ยน behavior และบันทึกเฉพาะคำที่จำเป็น |
| Research | [research](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/research/SKILL.md): primary sources, claim-level citation, artifact เดียว | Scout ระหว่าง discovery | หลักฐานเข้าถึงได้และข้อเท็จจริงไม่ปน assumption; ไม่บังคับ report ใหม่ทุก lookup |
| Spec faithful ต่อสิ่งที่ตกลง | [to-spec](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/to-spec/SKILL.md): synthesis; ไม่เปิดสัมภาษณ์ใหม่; เช็ก test seams กับผู้ใช้ | มี approval และ self-review | ไม่มีเรื่องแต่งเพิ่มจากช่อง template; decisions/changes ย้อนกลับไปยังคำตอบหรือหลักฐานได้ |
| วิธีพิสูจน์ | [to-spec](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/to-spec/SKILL.md): test seams และ Testing Decisions | `proven by` ต่อ criterion | เก็บทั้ง observable criterion และจุดทดสอบที่เหมาะสมโดยไม่บังคับจำนวน seam |
| งานเล็ก | [บทความ](https://www.aihero.dev/skills-to-spec)แนะนำข้าม to-spec ถ้างานอยู่ใน session เดียว | R0–R2 ลดขั้นตอน; one-session Define ยังใช้ full template | Compact contract ใน template เดิม; ไม่บังคับไฟล์ scratch เพียงเพื่อ lint ข้อความสั้น |
| งานหลาย session | [wayfinder](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/wayfinder/SKILL.md): map, fog, frontier, decision tickets | `chart-work` มีแกนนี้แล้ว | รักษาแผนที่ขนาดเล็ก, ผลตัดสินใจไม่ซ้ำ, เปลี่ยนใจแล้วปรับเฉพาะส่วนที่ได้รับผล |
| ส่งต่อ plan/tickets | [to-tickets](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/to-tickets/SKILL.md) เป็น Plan phase; slices + blocking edges + approval | write-plan มี slices/tests/coverage และ team issues เสริม | Define ส่ง contract ครบ; Plan ไม่รื้อ scope หรือลอบเพิ่ม requirement |
| ต้นทุนและความทนต่อข้อผิดพลาด | ขึ้นกับโมเดล/harness; ไม่มี benchmark ใน audit นี้ | เช่นกัน | วัดผลตาม §11 ไม่ตัดสินจาก prompt size หรือจำนวน gates |

ข้อควรระวัง: `grill-me` เป็น wrapper เพียง 22 คำ แต่เรียก `grilling` อีก 319 คำ ส่วน `grill-with-docs` เรียกทั้ง `grilling` และ `domain-modeling` การเทียบเฉพาะ wrapper กับ Rolepod ทั้ง skill จะทำให้ต้นทุนดูต่างเกินจริง จำนวนคำเป็น whitespace count ไม่ใช่ token usage

## 4. แนวทางที่เลือกและ non-goals

**เลือกปรับภายใน skill เดิม**: discovery policy เดียว, glossary แบบมีเหตุให้บันทึก, proof contract, compact/file output ใน template เดียว และชุดกรณีทดสอบเล็ก ๆ

ไม่เลือกเพิ่ม skills แยกตาม Matt เพราะ Rolepod มีช่องทางเหล่านี้แล้วและทำให้ router/การเรียกใช้ซ้ำซ้อน ไม่เลือกเพิ่ม state engine หรือ semantic validator เพราะยังไม่มีผลวัดที่คุ้มต้นทุน

สิ่งที่อยู่นอกงานนี้:

- เพิ่ม phase, skill, specialist role, config option หรือ dependency ใหม่
- ทำ interview UI, question graph engine, database หรือ glossary service
- บังคับ research agent, decision map, prototype หรือ cross-family review ทุกงาน
- เพิ่ม approval gate ใหม่ หรือยกเลิก approval เดิมทั้งหมด
- ทำ JSON decision ledger เป็น artifact แยกทุก session
- เปลี่ยน `write-plan` ให้เป็น Define อีกชั้น หรือย้าย to-tickets มา write-spec
- เปลี่ยน cross-family runner, pool defaults, timeouts หรือจำนวนรอบ reviewer
- เพิ่ม model calls ลง default CI หรือสร้าง evaluation platform
- ติดตั้ง/อัปเกรด plugins ทั้งเครื่อง หรือทำ release โดยอัตโนมัติ

รักษา cap ที่ repo ตรวจอยู่: phase `SKILL.md` ≤190 lines และ supporting files ของ write-spec ≤5 ไฟล์ ปัจจุบันใช้ครบ 5 แล้ว การลดบรรทัดต้องลดเนื้อหาซ้ำ ไม่อัดย่อหน้ายาวเพื่อหลบ cap [lean-surface](/Users/nuttaruj/Project/rolepod/tests/static/lean-surface.sh:73)

## 5. Behavior contract ที่ต้องได้

### WS1 — Discovery ไม่มีเพดานตัวเลข

- ลบ `up to ~5 per round` จาก skill หลัก
- เปลี่ยน `Ask one question at a time` ใน question bank เป็นการอ้าง policy ใน skill หลัก ไม่คัดลอก policy ยาวอีกชุด
- เปลี่ยน hard stop “goal ยังไม่ชัดหลัง 5 คำถาม” เป็นการตอบสนองต่อการไม่คืบหน้า: ถ้าคำตอบรอบล่าสุดไม่ช่วยปิดประเด็นหรือโจทย์ย้อนแย้ง ให้ชี้ข้อที่ติดและใช้สองกรอบที่เป็นรูปธรรม/ตัวอย่างให้ตัดสินใจ ไม่ตั้งเลขใหม่แทน 5
- ถ้า framing/ตัวอย่างยังไม่ทำให้ตัดสินใจได้เพราะขาดข้อมูล ผู้มีอำนาจตัดสินใจ หรือผู้ใช้ยังไม่พร้อม ให้หยุด discovery เป็น `BLOCKED` บันทึก open decision และสิ่งที่ต้องมีเพื่อ resume ห้ามถามรูปเดิมวนหรือเติมคำตอบแทนผู้ใช้
- ถามทุกคำถามบน frontier ปัจจุบันที่มีสาระ ไม่ตั้งเพดานจำนวนต่อรอบหรือทั้ง session
- เมื่อ frontier ยาว ให้จัดหมวดและทำคำถามสั้นลง ไม่ลบคำถามสำคัญเพื่อให้ดู lean
- Native question UI ที่จำกัดจำนวนต่อครั้งเป็นข้อจำกัดการส่ง ไม่ใช่ขอบเขต reasoning: แบ่งส่งหรือใช้ text fallback ตามความสามารถและกฎของ host โดยไม่ทำคำถามตกหล่น

ข้อความ policy แกนกลางที่เสนอให้นำไปปรับใช้:

```text
Ask every material question on the current frontier: its prerequisites
must already be settled, and a different answer must change the scope,
observable behavior, constraints, or verification. Do not impose a fixed
question count. Group a large frontier by topic. Defer dependent questions,
research facts yourself, and never re-ask a settled decision without new
evidence that makes it relevant again.
```

### WS2 — ถามเฉพาะการตัดสินใจที่ผู้ใช้ต้องตอบ

ก่อนถาม ตรวจว่าคำตอบอยู่ในข้อความก่อนหน้า, spec เดิมที่ตรวจแล้ว, repo/docs หรือสิ่งที่ผู้ใช้มอบหมายให้ตัดสินใจเองหรือไม่

ถามเมื่อคำตอบต่างกันแล้วเปลี่ยนเป้าหมาย, scope, observable behavior, ข้อจำกัด, เกณฑ์พิสูจน์ หรือ trade-off สำคัญ ถ้าทางเลือกเป็นรายละเอียด routine ที่ผู้ใช้มอบหมายแล้ว ให้เลือกตาม pattern ของ repo

แต่ละคำถามประกอบด้วยประเด็นสั้น ๆ, เหตุผลที่ต้องตัดสินใจ, ทางเลือกเมื่อมีทางเลือกจริง และ default พร้อมเหตุผล ไม่ฝืนทำ multiple choice ให้คำตอบที่ควรเป็นข้อเท็จจริง/รายละเอียดเปิด

- ผู้ใช้ตอบบางข้อ เช่น `1a 3c`: ปิดเฉพาะข้อที่ตอบ ข้อที่เหลือยังเปิด ห้ามตีความว่าเลือก default ทั้งหมด
- ผู้ใช้ตอบ `defaults`: ใช้ default เฉพาะคำถามและคำแนะนำที่ได้แสดงในรอบนั้น ห้ามขยายเป็นอนุมัติเรื่องใหม่หรือการเผยแพร่
- ความเงียบ/เวลาที่ผ่านไปไม่ใช่การอนุมัติ
- เคยตอบแล้วไม่ถามใหม่ เว้นแต่มีข้อเท็จจริงหรือคำสั่งใหม่ที่เปลี่ยนคำตอบ ต้องบอกว่ามีอะไรเปลี่ยน
- ถ้าถามต่อก็ไม่ช่วย เช่น ความรู้สึกของ UI ต้องทดลอง ให้ใช้ตัวอย่าง/ภาพ/demo ที่เล็กที่สุดแล้วรอ feedback แทนคำถามนามธรรมต่อเนื่อง
- ไม่บังคับ 2–3 approaches เมื่อมีเพียงทางเดียวที่ตรงข้อจำกัดจริง ช่อง rejected approaches อธิบายสั้น ๆ ว่าไม่มี alternative ที่มีสาระได้

### WS3 — จบตามความพร้อมส่งต่อ ไม่จบตามจำนวนข้อ

พร้อมส่ง `write-plan` เมื่อทั้งหมดต่อไปนี้เป็นจริง:

1. เป้าหมาย actor และขอบเขต/สิ่งที่ไม่ทำชัดเจนตามงาน
2. Current behavior ที่ใช้ตัดสินใจตรวจจากหลักฐานแล้ว หรือระบุว่าเป็นพื้นผิวใหม่
3. Desired behavior และกรณีสำคัญทั้ง success/error/boundary ไม่ตีความได้สองทางที่เปลี่ยน plan
4. ข้อจำกัดและความเสี่ยงที่เกี่ยวข้องได้รับการตัดสินใจแล้ว ไม่ต้องกรอกความเสี่ยงที่งานไม่ได้แตะ
5. Success criteria เป็น pass/fail และมี observation/test seam ที่พิสูจน์ได้
6. ไม่มี product decision หรือ fact ที่ยังไม่รู้ซึ่งเปลี่ยน scope/approach/acceptance อย่างมีสาระ
7. ผู้ใช้อนุมัติทิศทางและ artifact ตาม mode/กฎของ host; ใช้การอนุมัติที่มีอยู่แล้วเมื่อครอบคลุมเรื่องเดิมจริง

คำว่า “frontier ว่าง” เพียงอย่างเดียวไม่พอ ถ้ายังมีคำถามติด research หรือ prerequisite อยู่ ห้ามตีความว่าจบ ต้องตรวจ unresolved decisions ทั้งหมดที่มีสาระกับ slice นี้

รายละเอียด implementation ที่มอบหมายให้ `write-plan` อยู่แล้วไม่ใช่ unresolved product decision ห้ามยื้อ Define เพื่อระบุทุกไฟล์ ทุก function หรือทุก test command

Unknown ที่ตอบไม่ได้วันนี้: แยกเป็น research/probe decision ที่ต้องปิดก่อน หรือกำหนดเป็น non-goal/follow-up โดยมีเหตุผลและความเห็นชอบ ไม่ฝังเป็น assumption ใน spec ที่อ้างว่าพร้อมแล้ว

### WS4 — Evidence และคำตอบต้องแยกจากกัน

เก็บบันทึกสั้นในบริบท/เอกสารที่มีอยู่ แยกได้ว่าอะไรคือ:

- คำตอบ/การตัดสินใจของผู้ใช้
- ข้อเท็จจริงที่ตรวจจาก file, command output หรือ primary source
- ข้อเสนอของ agent ที่ยังไม่ได้รับการตัดสินใจ
- ประเด็นเปิดที่ยังขวางการส่งต่อ

ไม่ต้องมี JSON schema หรือไฟล์ ledger เพิ่ม ขณะคุยใช้สรุป delta สั้น ๆ; file mode เก็บเฉพาะการตัดสินใจ/หลักฐานที่จำเป็นต่อการทำต่อ

ข้ออ้างทางเทคนิคที่กำหนด approach ต้องมี pointer ตรวจต่อได้: path + symbol/line/commit สำหรับ repo หรือ URL + รุ่น/วันที่เมื่อข้อเท็จจริงเปลี่ยนตามเวลาได้ ค้นข้อมูลที่เป็น facts เองและอย่าให้ user confirm ข้อเท็จจริงแทนการตรวจ

Scout ใช้เมื่อมีงานค้นที่เป็นอิสระและมากพอ งานอ่านไฟล์เดียวไม่ต้อง dispatch ผู้รับงานส่งข้อสรุปพร้อม source ต่อ claim; บันทึกเป็น research file เฉพาะเมื่อเป็นงานค้นจริงหรือจำเป็นต้องใช้ข้าม session มิฉะนั้นใส่ pointer ใน spec เดิม

### WS5 — Domain terms แบบพอเหมาะ

อ่าน glossary/CONTEXT ที่ repo มีอยู่ก่อน หากไม่มีและไม่มีศัพท์ใหม่/กำกวม ไม่สร้างไฟล์

เมื่อคำเช่น account, cancel, member หมายได้หลายอย่างและคำตอบเปลี่ยน behavior ให้เสนอคำนิยามพร้อมตัวอย่างขอบเขต ตรวจเทียบ code แล้วถามเฉพาะส่วนที่ผู้ใช้ต้องตัดสินใจ

เมื่อคำนิยามตกลงแล้ว ให้บันทึกใน glossary เดิมตาม convention ของ repo หากคำใช้เฉพาะ feature เดียว เก็บหนึ่งบรรทัดใน spec ได้; สร้าง glossary ใหม่เมื่อมีศัพท์ที่จะใช้ซ้ำจริง ห้ามใช้ glossary เป็นที่เก็บ spec/แผน/implementation details

ADR ใช้กฎเดิมทั้งสามข้อ: ย้อนกลับแพง, ไม่มีบริบทแล้วน่าแปลกใจ, มี trade-off จริง ไม่เพิ่ม ADR ต่อทุกคำตอบ

### WS6 — เกณฑ์สำเร็จและจุดทดสอบต้องสัมพันธ์กัน

ใช้ success criterion รูปแบบ “เงื่อนไขตั้งต้น → การกระทำ → ผลที่สังเกตได้” แล้วระบุ `proven by` ที่เหมาะสม เช่น API response, state หลัง transaction หรือ UI interaction

ระบุ test seam ที่มีอยู่และเกี่ยวข้อง เช่น public API/หน้าจอ/CLI แทนการเริ่มจาก private function ถ้าต้องเพิ่ม seam ให้อธิบายเหตุผล ไม่ตั้งเป้าว่าทุกงานต้องมีเพียงหนึ่ง seam

การตรวจ seam กับผู้ใช้รวมในรอบที่ตัดสินใจ acceptance ได้ ไม่เปิด approval ceremony ใหม่เมื่อ seam เดิมตรวจพฤติกรรมที่ตกลงแล้วได้ตรงและไม่มี trade-off เพิ่ม

`write-spec` ระบุว่าจะพิสูจน์อะไรและตรงไหน ส่วน `write-plan` ระบุไฟล์ ลำดับ assertion และคำสั่งทดสอบที่รันได้ ห้ามแต่ง test command ว่ามีอยู่แล้วทั้งที่ยังไม่ได้ตรวจ

ตัวอย่าง: “CSV มีแถวตรงกับผลการกรองทุกหน้า” → prove ผ่าน export endpoint และเทียบ row set; “ไม่มีผลลัพธ์” → ได้ไฟล์ header-only ห้ามเติม Excel/PDF เพราะ template ยังดูสั้น

### WS7 — Compact และ durable contract ใช้ template เดียว

คง routing R0–R2 เดิม งานที่ไม่ควรเข้า Define ไม่ถูกลากมาสัมภาษณ์เพราะมี template ใหม่

**Compact:** งานที่อยู่ใน session เดียว, ไม่แตะ high-risk และไม่ต้องเก็บประวัติ repeat feature ตามกฎเดิม ใช้ semantic fields ชุดนี้ใน `templates/spec-template.md` เดิม:

- Goal/actor และ current → desired delta
- Scope/non-goals และ constraints ที่เกี่ยวข้อง
- Acceptance + วิธีพิสูจน์/จุดทดสอบ
- Chosen direction และเหตุผลเฉพาะที่จำเป็น
- Open decisions: none หรือระบุสิ่งที่ยังขวางการส่งต่อ

Fields รวมอยู่ใน bullets/paragraph เดียวกันได้ ไม่มีจำนวนบรรทัดตายตัว ไม่มีหมวดที่ต้องเติมเนื้อหาเพื่อให้ครบฟอร์ม ไม่เขียน scratch file เพียงเพื่อเรียก placeholder lint กับข้อความ compact; ยังต้อง self-review ความครบและไม่แต่งข้อสรุป

**Durable:** multi-session/high-risk/repeat feature ใช้ full template และตำแหน่งไฟล์เดิม เก็บ current/desired delta, acceptance, constraints/risk, approaches, หลักฐานสำคัญ และศัพท์/test seam เท่าที่ต้องใช้ ไม่สร้าง “full-template-v2” แยกอีกไฟล์

**Approval:** รักษา Gate 1; direction ที่ผู้ใช้เพิ่งอนุมัติชัดแล้วไม่ต้องถามซ้ำ Gate 2 ยังคงอยู่สำหรับ written file ที่ผู้ใช้ยังไม่ได้ตรวจ เมื่อแก้ตามคำสั่งที่ชัด ไม่เพิ่ม gate ใหม่เพียงเพราะมีการบันทึกซ้ำ; ถ้าเนื้อหาทิศทางเปลี่ยนต้องยืนยันส่วนที่เปลี่ยนตาม scope ของการอนุมัติเดิมและกฎ host

แก้ Mermaid workflow ให้ลำดับ self-review/critique/Gate 1 ตรงกับข้อความขั้นตอน และแยก “working draft” ก่อน Gate 1 ออกจาก “final contract” ที่ส่งต่อหลังอนุมัติ

### WS8 — ปรับ placeholder lint โดยไม่สร้าง semantic engine

เลือกใช้ marker เฉพาะสำหรับช่องที่ยังกรอกไม่เสร็จ เช่น `[[FILL: criterion]]` ใน template แทนการเหมารวม angle brackets ทุกชนิด เปลี่ยน documented lint และ test fixture ให้ตรวจ marker เดียวกัน

ข้อกำหนดขั้นต่ำ:

- Unfilled template และ marker ที่หลงเหลือต้องไม่ผ่าน
- Requirement ที่มี `<h1>`, `List<T>`, URL หรือ literal code ปกติต้องผ่านเมื่อไม่มี marker
- Path ไม่มี/อ่านไม่ได้ หรือ command error ต้องเป็น error ไม่ถูกแปลงเป็น “ไม่พบ placeholder” แล้วผ่าน
- การมีคำว่า TODO/TBD ใน literal ของงานไม่ได้พิสูจน์ว่าเป็นช่อง template ใช้ self-review บริบท ไม่ขยาย blacklist จนทำลายข้อความที่ถูกต้อง
- Lint ไม่รับรองว่า spec ไม่ขัดกัน/ตรงเจตนา/ได้รับอนุมัติ สิ่งเหล่านี้ต้องใช้ semantic review และ behavioral evidence

ใช้ inline command ที่เข้ากับ skill เดี่ยวได้ก่อน ไม่เพิ่ม CLI/dependency/parser ถ้าไม่จำเป็น Update test `LINT_RX` และข้อความใน skill พร้อมกันเพราะปัจจุบันทั้งสองเก็บคำสั่งนี้ไว้

### WS9 — Critique ถูกจำกัดต้นทุน แต่ไม่จำกัดความครบของคำตอบ

คง opt-in, ไม่เปิด pool แทนผู้ใช้, ไม่เพิ่มจำนวน critic runs, ไม่แก้ runner ผลจาก critic ยังจำกัด ≤5 items ได้ เพราะเป็น shortlist ของความเสี่ยง

ใน question bank เปลี่ยน “ONE extra discovery round ... cap 5” ให้หมายถึง triage critic หนึ่งครั้ง แล้วนำ unresolved items กลับเข้า discovery ปกติ หากคำตอบเผย prerequisite/คำถามใหม่ที่มีสาระ ให้ถามต่อได้โดยไม่เรียก critic ซ้ำ

Critic ไม่พร้อม/ปิดไว้ไม่ใช่เหตุให้หยุด แต่ประเด็นสำคัญที่ critic พบแล้วไม่ได้รับข้อสรุปยังเป็น blocker ตาม WS3 ห้ามใช้ “critique never blocks” เป็นใบอนุญาตให้ส่ง spec ที่รู้ว่ากำกวม

### WS10 — Map และ plan handoff ใช้ของเดิม

ใช้ chart-work เมื่อยังระบุ slices ไม่ได้เพราะการตัดสินใจค้าง ไม่ใช้เพียงเพราะมีคำถามจำนวนมากหรือแตะหลายไฟล์

คง discuss/probe ให้ผู้ใช้เป็นผู้ตัดสิน คง prototype เป็นของทดลองที่ไม่ merge คง investigate แบบค้นหลักฐาน และจำกัด unblock ให้ทำเพื่อปลดล็อก decision เท่านั้น

แก้ความสอดคล้องเล็กน้อยของ map schema: ปัจจุบัน status แสดง `open | resolved` แต่ขั้นตอนกล่าวถึง closed/ruled out ให้ระบุสถานะปิดนอก scope ให้ชัดใน schema เดิม เช่น `open | resolved | ruled-out` ไม่เพิ่ม ticket engine

เมื่อผู้ใช้เปลี่ยนใจ แก้ resolution/คำถามที่ได้รับผล ระบุว่าอะไรแทนข้อสรุปเดิม เก็บเหตุผลสั้น ๆ ไม่เปิดคำถามทุกข้อใหม่; map ยังเป็น index และเก็บรายละเอียดที่ ticket ที่เดียว

Spec ที่ส่ง Plan ต้องทำให้เขียน requirement → task และ task → requirement ได้ ใช้ชื่อ criterion/ข้อความอ้างอิงเดิมได้ ไม่ต้องบังคับ global ID scheme ห้าม planner เพิ่ม scope โดยอ้างช่องว่างที่ agent แต่งเอง

## 6. ตัวอย่างพฤติกรรมที่ต้องเปลี่ยน

### Frontier ใหญ่แต่ถามได้จริง

ผู้ใช้บอก feature, actor, data source และข้อจำกัดทางเทคนิคครบแล้ว แต่ยังมี business decisions อิสระ 7 ข้อ

- เดิม: อาจหยุดที่ 5 ข้อ หรือถามทีละข้อเมื่อโหลด question bank
- ใหม่: ถามทั้ง 7 ข้อในรอบเดียว แบ่งหมวดตามเรื่องและให้คำแนะนำต่อข้อ ไม่ถามข้อมูล actor/data source ซ้ำ
- ข้อยกเว้น: host UI รับได้ครั้งละน้อยกว่า 7 ให้จัดส่งตามความสามารถโดยนับเป็น frontier เดียว; ไม่ลงโทษข้อจำกัด host ว่า skill ไม่ครบ

### คำถามติด dependency

ยังไม่รู้ว่า “export” หมายถึงหน้าปัจจุบันหรือผลกรองทุกหน้า จำนวนข้อมูลและวิธีส่งไฟล์จะต่างกัน

- ถาม semantics ของ export ก่อน
- ค้น pagination/ข้อจำกัด endpoint ไปพร้อมกัน
- ยังไม่ถาม “เอา link ไฟล์ไปแสดงหน้าไหน” จนยืนยันว่าต้องสร้าง async file จริง

### User เปลี่ยนความหมายของคำ

เดิมตกลง cancellation เป็นการยกเลิกทั้ง order ต่อมาขอ partial cancellation

- ชี้ว่าข้อสรุปเดิมเปลี่ยนตรงไหน ตรวจ model ปัจจุบัน แล้วเปิดเฉพาะคำถามที่กระทบ partial cancellation
- ปรับศัพท์/desired delta/acceptance ที่เกี่ยวข้อง ไม่ถาม actor และข้อจำกัดเดิมซ้ำ

## 7. Files to touch

ทุก path ต่อไปนี้มีอยู่แล้วและอ่านส่วนที่เกี่ยวข้องใน audit/handoff นี้ ยกเว้นไฟล์ที่ระบุ **new** Session ถัดไปต้องตรวจ HEAD/diff อีกครั้งก่อนแก้

| File | งาน |
|---|---|
| [core/skills/write-spec/SKILL.md](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/SKILL.md) | WS1–WS9: policy หลัก, convergence, modes, proof, approval, lint และ diagram |
| [core/skills/write-spec/references/question-bank.md](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/references/question-bank.md) | WS1–WS5, WS9: skip rules, terms, partial answers, critique follow-ups; อ้าง policy เดียว |
| [core/skills/write-spec/templates/spec-template.md](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/templates/spec-template.md) | WS4–WS8: compact/full ในไฟล์เดียว, evidence/terms/seams เท่าที่จำเป็น, marker ใหม่ |
| [core/skills/write-spec/examples/spec-examples.md](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/examples/spec-examples.md) | ปรับตัวอย่างเดิมและเพิ่ม compact contrast สั้น ๆ; รักษา Why good wins |
| [core/skills/write-spec/references/chart-work.md](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/references/chart-work.md) | WS10: status ให้ตรง exit rule และการเปลี่ยน decision |
| [tests/integration/cases/spec-lint.sh](/Users/nuttaruj/Project/rolepod/tests/integration/cases/spec-lint.sh) | WS8: marker/error/false-positive fixtures และ sync กับ documented command |
| [tests/integration/cases/feature-from-spec.sh](/Users/nuttaruj/Project/rolepod/tests/integration/cases/feature-from-spec.sh) | Contract consistency: policy เก่าไม่กลับมา, semantic handoff/modes ยังอยู่; ไม่อ้างว่า grep พิสูจน์ agent behavior |
| [tests/integration/README.md](/Users/nuttaruj/Project/rolepod/tests/integration/README.md) | แยก wiring/command fixtures ออกจาก behavioral protocol; เลิกข้อความที่ทำให้ดูเหมือน structural test ครอบคลุมการโต้ตอบทั้งหมด |
| [Makefile](/Users/nuttaruj/Project/rolepod/Makefile) | แก้เฉพาะคำอธิบายขอบเขตทดสอบหากเพิ่ม behavioral protocol; ไม่เพิ่ม live model calls ใน default targets |
| `/Users/nuttaruj/Project/rolepod/tests/behavior/write-spec.md` — **new** | Case fixtures, answer key, scoring และวิธี replay แบบหลาย turn ในไฟล์เดียว; ไม่มี runner/framework ใหม่ |

อ่านเพื่อรักษา boundary แต่ไม่แก้โดยอัตโนมัติ: [using-rolepod](/Users/nuttaruj/Project/rolepod/core/skills/using-rolepod/SKILL.md), [write-plan](/Users/nuttaruj/Project/rolepod/core/skills/write-plan/SKILL.md), [team-issues](/Users/nuttaruj/Project/rolepod/core/skills/write-plan/references/team-issues.md), [scope-splitting](/Users/nuttaruj/Project/rolepod/core/skills/write-spec/references/scope-splitting.md), [lean-surface](/Users/nuttaruj/Project/rolepod/tests/static/lean-surface.sh), [renderer](/Users/nuttaruj/Project/rolepod/build/render.sh)

Generated copies ใต้ `plugins/rolepod/`, `plugins/rolepod-codex/`, `plugins/rolepod-cursor/` และ `build/rendered/` ให้สร้างด้วย renderer ห้ามแก้แต่ละ copy ด้วยมือ หาก router มีข้อความขัดกับ modes ใหม่จริง ให้แก้เฉพาะข้อความนั้นพร้อมอธิบายเหตุผล ไม่ขยาย scope ไป redesign router

## Parallel layout

Sequential — single implementation owner งานนี้แก้ policy/template ที่ผูกกัน การแบ่งคนละ agent แก้ไฟล์เดียวกันเพิ่มความเสี่ยงมากกว่าลดเวลา ให้ reviewer/QA อ่านอย่างอิสระได้ แต่ไม่ต้องทำ coding fan-out

## 8. Tasks และลำดับทำงาน

คำสั่งด้านล่างรันจาก repository root ของ checkout ที่ session ถัดไปใช้งาน

### Task 1: ทำ discovery policy ให้สอดคล้อง

- [ ] **Files:** SKILL.md, question-bank.md, feature-from-spec.sh ตาม §7
- [ ] **Change:** WS1–WS3 และ WS9; ลบเพดาน discovery ทั้งสองแห่งกับคำสั่ง one-at-a-time; แยก critic budget ออกจากคำถามที่ต้องปิด
- [ ] **Test / evidence:** เพิ่ม targeted contract assertions สำหรับข้อความ policy ขัดกัน และตรวจคำตอบบางส่วน/blocked research ใน behavioral cases §10
- [ ] **Expected failing signal:** baseline มีข้อความเก่าทั้งสามตำแหน่ง; assertions ใหม่ต้องพบ regression ก่อนแก้
- [ ] **Command:** `bash tests/integration/cases/feature-from-spec.sh`
- **Done when:** ไม่มีคำสั่งที่ตัด discovery เพราะครบจำนวน; critic ยังคง opt-in และหนึ่งรอบต่อ draft

### Task 2: ทำ contract ให้ครบและสั้นตามงาน

- [ ] **Files:** SKILL.md, question-bank.md, spec-template.md, spec-examples.md
- [ ] **Change:** WS4–WS7; grounded facts, terms, proof seams, compact/full, provenance และ gate semantics; diagram ตรงข้อความ
- [ ] **Test / evidence:** เติม compact export กับ durable repeat/high-risk example จากตัวอย่างเดิม; reviewer trace ทุกข้อสรุปกลับไปยัง fixture facts/user decisions; ไม่มีคำถาม/approach ที่แต่งเพื่อเติมฟอร์ม
- [ ] **Command:** `bash tests/integration/cases/feature-from-spec.sh`
- **Done when:** ตัวอย่างและ policy ตรงกัน; compact ไม่ต้อง full template/scratch lint; file mode รักษาการตรวจ artifact; command ผ่านเป็น wiring proof เท่านั้น ต้องตรวจตัวอย่างด้วย

### Task 3: แก้ placeholder false positives

- [ ] **Files:** SKILL.md, spec-template.md, spec-lint.sh; ปรับตัวอย่างที่มี marker หากเกี่ยวข้อง
- [ ] **Change:** WS8 ใช้ marker เฉพาะและตรวจ command error; ไม่เพิ่ม semantic parser
- [ ] **Test / evidence:** marker, unfilled template, missing input, valid HTML/generic/literal code; รวมตัวอย่างที่ semantic-invalid แต่ marker-clean เพื่อยืนยันขอบเขต lint โดยตรง
- [ ] **Expected failing signal:** regex เดิมปัด `<h1>` และ `List<T>` ตก; error handling เดิมต้องไม่ถูกนำไปใช้เป็น no-match pass
- [ ] **Command:** `bash tests/integration/cases/spec-lint.sh`
- **Done when:** placeholder/error cases ถูกแยกจาก clean input และ actual lint command กับ fixture ใช้กฎเดียวกัน

### Task 4: รักษา decision map และ handoff

- [ ] **Files:** chart-work.md, feature-from-spec.sh; SKILL.md เฉพาะ reference ที่จำเป็น
- [ ] **Change:** WS10; schema กับ ruled-out exit สอดคล้อง, เปลี่ยนใจไม่ reopen ทุกเรื่อง, ไม่ build จาก map
- [ ] **Test / evidence:** ตรวจ map example ที่มี resolved + ruled-out ไม่มี ticket ค้าง และ replay decision-change case; planner สร้าง task trace ได้โดยไม่เพิ่ม requirement
- [ ] **Command:** `bash tests/integration/cases/feature-from-spec.sh`
- **Done when:** map contract ใช้ได้ตามสถานะที่ระบุ และ Define/Plan ownership ไม่ซ้อนกัน

### Task 5: เพิ่ม protocol ทดสอบพฤติกรรมขนาดเล็ก

- [ ] **Files:** tests/behavior/write-spec.md ใหม่, tests/integration/README.md, Makefile เฉพาะคำอธิบาย
- [ ] **Change:** เขียน fixtures ตาม §10 พร้อม answer key แยกจาก input ของ agent และ rubric §11; ไม่เพิ่ม model execution ลง CI
- [ ] **Test / evidence:** แต่ละกรณีมี known decisions/dependencies/expected observable outcome ที่ reviewer ให้ verdict ซ้ำได้; คำอธิบายระบุชัดว่า protocol ที่เขียนแล้วไม่ใช่ผลรันทดสอบ
- [ ] **Command:** `test -s tests/behavior/write-spec.md && git diff --check`
- [ ] **Manual review:** ตรวจ B1–B12 ทีละกรณีว่ามี initial prompt, repo facts, answer key, prerequisites, user turns และ expected observable result ครบ; บันทึก case ที่ยังตีความได้หลายทางในไฟล์ protocol แล้วแก้ก่อนปิดงาน
- **Done when:** session อื่นเปิดไฟล์เดียวแล้ว replay ได้และ manual review ครบ; command ข้างบนตรวจเพียงไฟล์มีอยู่/format ไม่ใช่หลักฐานความถูกต้องของ fixture หรือพฤติกรรม agent

### Task 6: Render และตรวจการส่งมอบ

- [ ] **Files:** generated outputs ของ source ที่เปลี่ยนเท่านั้น
- [ ] **Change:** รัน `make render` เพื่อสร้างผลลัพธ์ที่ตั้งใจแก้ ตรวจ source/generated diff ของทุก adapter ที่ได้รับผล แล้ว stage เฉพาะไฟล์ของงานที่ตรวจแล้วเป็น expected baseline ก่อนรัน render-clean; ไม่ใช้ `git add .` หรือ stage งาน session อื่น
- [ ] **Test / evidence:** focused tests ผ่านก่อน แล้ว release checks ตามคำสั่งด้านล่าง; แยก PASS/SKIP/FAIL จริง
- [ ] **Command:** `make test-all && git diff --check && git diff --cached --check`
- **Done when:** generated copies ตรง source, ไม่มี cap ที่ถูกขยายเพื่อหลบปัญหา, test ไม่มี failure; skips ต้องระบุ coverage ที่ยังไม่ได้พิสูจน์
- **On fail:** แก้ข้อผิดพลาดที่เกิดจากงานนี้อย่างเจาะจง ถ้า baseline เสียอยู่แล้วให้แยกหลักฐานและไม่รวม unrelated fix เงียบ ๆ

การ render ครั้งแรกสร้าง expected outputs ส่วน render ภายใน `make test-all` ตรวจว่าสร้างซ้ำแล้วไม่ drift; [Makefile:93](/Users/nuttaruj/Project/rolepod/Makefile:93) ตรวจ unstaged diff ของ generated tree หากไม่ stage ผลลัพธ์ที่ตั้งใจแก้ก่อน gate นี้จะเห็นงานใหม่เป็น drift การ stage เป็นเพียง local index operation ไม่ใช่ commit/push/release

## Conditional evaluation — หลัง implementation complete

- [ ] **Files:** ใช้ tests/behavior/write-spec.md; บันทึก evidence ใต้ `.rolepod/evidence/` ของ isolated evaluation checkout ตาม convention ที่มีอยู่
- [ ] **Change:** รันกรณีสำคัญแบบหลาย turn และ pilot comparison ตาม §11 โดยไม่สร้าง framework ใหม่
- [ ] **Test / evidence:** transcript, exact loaded source refs, model/harness settings, rubric per case, measured/unknown token and timing fields
- [ ] **Replay procedure:** ใช้ native interactive replay ของ harness ที่ตรวจว่ามีอยู่จริงใน session นั้น; ก่อนรันจด invocation/ขั้นตอนที่ทำซ้ำได้ลง evidence ห้ามแต่งคำสั่ง CLI ที่ยังไม่ตรวจหรือใช้ structural fixture แทนผลหลาย turn
- **Closure:** ปิดขั้นนี้ได้ด้วยผลรันจริง หรือสถานะ `NOT RUN` พร้อมเหตุผลและขั้นตอนรันต่อ; NOT RUN ปิดการรายงานสถานะได้แต่ไม่พิสูจน์ว่าพฤติกรรมผ่าน/เหนือ Matt และไม่ขวางการส่งมอบ Tasks 1–6 ที่ทำครบแล้ว

ขั้นนี้เป็น manual/interactive verification แบบมีเงื่อนไข จึงแยกจาก implementation tasks ที่มีคำสั่งรันได้แน่นอน การเขียน protocol และการรัน protocol ต้องเป็นคนละ checkbox/สถานะ

## 9. Spec coverage และหลักปฏิบัติเมื่อพบปัญหา

| Requirement | Tasks |
|---|---|
| WS1–WS3: discovery/convergence/non-repetition | 1, 2, 5; conditional evaluation §11 |
| WS4–WS7: evidence/terms/proof/compact/durable | 2, 5; conditional evaluation §11 |
| WS8: lint correctness and limits | 3, 6 |
| WS9: bounded critique without truncating discovery | 1, 5; conditional evaluation §11 |
| WS10: map and plan boundary | 4, 5; conditional evaluation §11 |
| No source/render drift or surface bloat | 6 |

ทุก task ต้องอธิบายได้ว่าทำ requirement ไหน ถ้างานใหม่ไม่เข้าตาราง ให้พักเป็น follow-up ไม่เติมเข้า scope อัตโนมัติ

## Failure policy

คำสั่งล้มเหลว → ตรวจสาเหตุ → แก้ให้น้อยที่สุด → รันคำสั่งเดิมซ้ำ ปฏิบัติตาม escalation/approval rules ที่ใช้จริงใน session นั้น ไม่เปิด cross-family pool หรือ bypass gate เองเพราะเอกสารนี้

หาก behavioral case ล้มเหลว ให้แยกก่อนว่าเกิดจาก skill, host/tool limit, fixture ที่ขัดกัน หรือ variance ของโมเดล ห้ามเติมกฎใหม่ทุกครั้งที่ได้คำตอบไม่ถูกใจ การแก้ต้องผูกกับ failure ที่ทำซ้ำได้

ก่อน edit ตรวจ `git status` และ concurrent sessions หากจะแก้ shared files ให้ใช้ isolated worktree ตามกฎ repo ไม่ตั้ง override เพื่อหลบการแยกงาน การสร้าง handoff ไฟล์ใหม่ในรอบนี้ไม่ได้อนุญาตให้ session ถัดไปแก้ shared source พร้อมอีก session

## 10. Behavioral cases ที่ต้องมี

สร้าง fixture แต่ละกรณีให้มี: initial prompt, repo facts, decision answer key, prerequisites, user turns ที่เกิดตามเงื่อนไข และ expected result อย่าใส่ answer key ทั้งหมดใน context ของ subject agent

| Case | โจทย์/เงื่อนไข | Observable pass |
|---|---|---|
| B1 Small clear change | เพิ่ม empty state; goal/ข้อความ/ตำแหน่งชัดแล้ว | ไม่เปิด discovery ซ้ำ; ใช้ route ที่เบาตาม scope; ไม่สร้าง full spec |
| B2 Seven ready decisions | actor/data source ชัด; มี 7 business decisions อิสระจริง | ครบ frontier โดยไม่หยุดที่ 5; คำถามกระชับ ไม่ประดิษฐ์ข้อเพิ่ม |
| B3 Dependency + research | child decision ต้องรอคำตอบ parent และ fact จาก repo | ถาม ready items ก่อน; ไม่มี speculative child question; ไม่ประกาศจบเพียงเพราะ ready frontier ว่างขณะ research ยังไม่จบ |
| B4 Partial answers | ตอบ `1a 3c` แล้วภายหลังตอบข้อที่เหลือ | ไม่เลือก default ให้ข้อที่ข้ามและไม่ถามข้อ 1/3 ซ้ำ |
| B5 Already answered | ผู้ใช้ให้ constraints และ acceptance ไว้แล้ว | ใช้คำตอบเดิม; ไม่ถามเรื่องที่ค้นจาก repo ได้; ไม่สร้าง choices ให้ routine detail |
| B6 Domain ambiguity | “account” มีสองความหมาย; glossary กับคำพูดไม่ตรง | ยืนยันเฉพาะความหมายที่เปลี่ยน behavior และบันทึกศัพท์ในที่เหมาะสม |
| B7 Evidence and seams | export ของ paginated list; ระบุขอบเขตแถวและ empty case | AC ตรวจได้; seam มีจริงหรือระบุว่าเสนอใหม่; ไม่แต่ง command/file ที่ยังไม่มี |
| B8 Change of mind | เปลี่ยน full cancellation เป็น partial หลังตัดสินใจบางข้อแล้ว | แก้เฉพาะ dependent decisions/criteria; เก็บเหตุผลเปลี่ยน; ไม่รื้อทุกคำถาม |
| B9 Approval and omission | agent เสนอ default แต่ผู้ใช้ยังไม่ตอบ หรือ written file ยังไม่ถูกตรวจ | ไม่อ้าง approved; ไม่ส่งต่อหรือ implement เกินอำนาจ; ใช้ approval เดิมเฉพาะเรื่องที่ครอบคลุม |
| B10 Critique follow-up | critic shortlist พบเรื่องที่คำตอบเปิด dependent question ใหม่ | triage หนึ่งครั้ง; ถาม material follow-up จนชัด; ไม่เรียก critic รอบสองและไม่ยกเลิกคำถามเพราะ cap |
| B11 Multi-session map | slices ยังไม่ชัด; มี decision ถูก ruled out แล้ว resume | ไม่สร้าง implementation ticket ล่วงหน้า; status/exit ถูก; ไม่ build จาก map; ไม่อ่านทุก ticket โดยไม่จำเป็น |
| B12 Fresh plan handoff | fresh session ได้ approved spec โดยไม่เห็น discovery transcript | เขียน task/verification trace ได้ครบ; ไม่มี material scope question ที่ spec ควรตอบ; ถ้าต้องถามเรื่อง repo implementation ถือเป็น Plan work ได้ |

B2 ต้องสร้างโจทย์ที่ทั้ง 7 ข้อเปลี่ยน implementation จริง มิฉะนั้นการไม่ถามข้อที่ไม่เกี่ยวข้องเป็นผลดี ไม่ใช่ fail B12 ต้องเปิดสิทธิ์อ่าน repo ให้ planner ตามปกติ ไม่บังคับเดา implementation จาก spec อย่างเดียว

## 11. การวัดเทียบที่ไม่ over engineer

### เริ่มจาก pilot เล็ก

เลือก 4 สถานการณ์ focused comparison: frontier ใหญ่, domain ambiguity + proof, partial answers และ spec ที่ต้องส่งต่อ fresh planner เปรียบเทียบ Rolepod candidate กับ Matt อย่างละหนึ่ง run ต่อสถานการณ์ รวม 8 บทสนทนาเป็น pilot ไม่ต้องรันทุก case ทุก model หลายสิบชุดก่อนเริ่มเรียนรู้

หน่วยเปรียบเทียบ focused = จาก initial request/facts ไปถึง approved contract ของ slice เดียวกัน ภายใต้ neutral top-level instructions และ tools ชุดเดียวกัน โหลดเฉพาะ skill/dependencies ที่แต่ละ arm ต้องใช้; ในกรณี handoff ให้ใช้ planner/probe แบบเดียวกันทั้งสอง arm เพื่อวัดว่า contract เพียงพอหรือไม่ ไม่วัดความเก่งของ planner คนละชุดแทนคุณภาพ spec

B1 เป็น regression ของ Rolepod router และถ้าจะเทียบกับ Matt ให้รายงานเป็น deployed-workflow experiment แยกจาก focused comparison เพราะ Matt มีการเลือก skill ด้วยผู้ใช้และสามารถข้าม to-spec ได้ ไม่มีเหตุให้รวมตัวเลขสองขอบเขตเป็นคะแนนเดียว

เก็บ baseline Rolepod เดิมสำหรับ regressions สำคัญอย่างน้อย frontier และ lint จาก evidence ที่มี; หากต้องกล่าวว่า “ปรับแล้วลดเวลา/คำถามกว่าเดิม” ต้องเพิ่มการรัน old/new ด้วยโจทย์เดียวกัน ไม่มีสิทธิ์อนุมานจากตัวอักษรที่ลบออก

หลัง pilot ทำซ้ำเฉพาะกรณีที่ผลแกว่ง/มี regression/ต้องยืนยันคำกล่าวเปรียบเทียบ ไม่กำหนดชุดนี้เป็น gate ทุก PR

### ทำให้การเทียบยุติธรรม

- Model, effort, tool permissions, repo snapshot, initial facts และ scripted user answers เหมือนกัน
- ใช้ skill dependencies ครบ: `grill-with-docs` ต้องได้ `grilling` และ `domain-modeling`; ไม่เทียบ wrapper เปล่ากับ Rolepod เต็มชุด
- Focused arms ต้องใช้ neutral instructions โดยไม่รับ Rolepod always-on guidance; ถ้าสภาพแวดล้อมแยกคำสั่งไม่ได้ ให้ระบุ contamination และห้ามใช้ run นั้นอ้าง focused parity
- ใช้ Matt ตาม workflow ที่เหมาะกับโจทย์ งานเล็กไม่บังคับ to-spec/to-tickets และทุกงานไม่บังคับ wayfinder
- แยกผล focused skill comparison ออกจาก deployed workflow ที่รวม router/hooks/optional reviews; อย่าโหลด Rolepod instructions เข้า arm ของ Matt แล้วเรียกว่าการทดลองอิสระ
- ใช้ profile/checkout สำหรับทดลองที่แยกได้ตามความสามารถจริง ไม่แก้ global config หรือปิด hooks ใน environment ผู้ใช้เพื่อทำ benchmark
- ให้ test driver ส่ง answer key ตามคำถามจริง ห้าม subject agent อ่าน answer key ล่วงหน้า หรือสวมบทผู้ใช้แล้วอนุมัติผลตัวเองในการใช้งานจริง
- Reviewer ใช้ rubric เดียวกันและหากทำได้ไม่เห็นชื่อ arm ห้ามให้คะแนนสูงเพราะ prose ยาวหรือมี headings มาก
- เก็บ interactive transcript จริง การอ่าน skill แล้วเขียนบทสนทนาที่คาดหวังเองเป็น example ไม่ใช่ behavior result

### Metrics

| Metric | วิธีนับ |
|---|---|
| Decision coverage | Material decisions ที่ถูกตัดสินใจถูกต้อง / material decisions ใน answer key; ไม่นับ routine implementation choices |
| Unsupported assumptions | ข้อสรุปที่เปลี่ยน scope/behavior โดยไม่มีคำตอบหรือหลักฐานรองรับ |
| Wasted questions | คำถามซ้ำ, repo-answerable, irrelevant หรือเรื่องที่มอบหมายให้ agent ตัดสินใจแล้ว; ไม่นับคำถามที่เกิดจากเปลี่ยนใจจริง |
| Dependency errors | ถาม child บน parent ที่ยังไม่ตกลง หรือประกาศจบทั้งที่ยังมี blocker |
| Proof coverage | Acceptance ที่มี observable outcome และวิธีพิสูจน์ที่ใช้ได้ / acceptance ทั้งหมด |
| Handoff defects | ประเด็นที่ fresh planner ต้องย้อนมาถามเพราะ spec ตกหล่นหรือขัดกัน; แยกจากการอ่านโค้ดตามหน้าที่ Plan |
| User burden | จำนวนรอบและคำถามที่มีสาระ/เสียเปล่า แยกกัน; จำนวนข้อเยอะไม่เท่ากับผลแย่ |
| Time | Agent active time, tool time และเวลารอคำตอบผู้ใช้แยกกัน; ถ้ารายงานรวมต้องระบุองค์ประกอบ |
| Cost | Actual input/output tokens รวม subagents ถ้า harness เปิดเผย; ถ้าไม่มีให้ UNKNOWN ห้ามแปลง word count เป็นตัวเลขวัดจริง |
| Artifact burden | จำนวนไฟล์ที่สร้างและขนาด contract ที่ผู้ใช้ต้องตรวจ; ห้ามให้การย่อจน requirement หายได้คะแนนดี |

### เกณฑ์ตัดสิน

- Functional acceptance: ไม่มี material decision ที่ตกหล่น/แต่งขึ้น, ไม่มี approval fabrication, acceptance และ fresh-plan trace ครบใน cases ที่รัน
- ต้องไม่แลกคำถามน้อยลงกับ decision coverage ที่ลดลง
- ผลเวลา/token ดีกว่าได้เมื่อวัดจริง; หากคุณภาพเพิ่มแต่ต้นทุนเพิ่ม ต้องรายงาน trade-off ไม่สรุปว่าชนะทุกมิติ
- ถ้า 4 pilot cases ผ่านทั้งหมด ให้รายงานเพียง “ผ่าน 4 cases ที่ทดลอง”; ข้อสรุปทั่วไปยังต้องข้อมูลเพิ่ม ไม่มี statistical confidence ที่สร้างจาก single run
- แยกผลแต่ละด้านเป็น `PASS / FAIL / NOT RUN / UNKNOWN` พร้อมหลักฐาน ไม่สร้างคะแนนรวมที่ซ่อนมิติแพ้

## 12. Definition of done

- [ ] WS1–WS10 มี implementation/หลักฐานหรือข้อจำกัดที่ระบุชัด ไม่มี requirement ถูกข้ามเงียบ ๆ
- [ ] ไม่มี arbitrary cap ใน user discovery และไม่มี one-at-a-time policy ที่ขัดกัน
- [ ] ไม่มีการปิด discovery ขณะ material blocker ยังเปิดอยู่
- [ ] Compact mode ลด artifact/approval ซ้ำโดยไม่ทำ semantics หรือวิธีพิสูจน์หาย
- [ ] Durable spec มี facts/decisions ที่ตรวจย้อนกลับได้และรักษา user approval
- [ ] Lint แยก placeholder จาก HTML/generics และไม่กลบ file/command errors
- [ ] Map status/decision revision และ Define → Plan boundary ตรงกัน
- [ ] Source และ generated copies ตรงกัน; tests ที่รันจริงผ่านและ skips ไม่ถูกนับเป็น pass
- [ ] ไม่มีเพิ่ม skill/phase/config/dependency/automatic reviewer run เพื่อทำงานนี้
- [ ] มี behavioral protocol ที่รันต่อได้ พร้อมระบุว่ากรณีใดรันแล้ว/ยังไม่รัน
- [ ] ถ้ากล่าวว่าเร็วกว่า ประหยัดกว่า หรือเทียบเท่า Matt ต้องมีผล measured comparison รองรับในมิตินั้น

Implementation complete กับ comparative superiority proven เป็นคนละสถานะ ส่งมอบ code ที่แก้ครบได้พร้อมข้อจำกัดการวัด แต่ห้ามเปลี่ยนข้อจำกัดนั้นเป็นคำกล่าวชนะที่ไม่มีหลักฐาน

## 13. ความเสี่ยงที่ต้องคุมระหว่างพัฒนา

| ความเสี่ยง | วิธีคุมที่เล็กที่สุด |
|---|---|
| เอา cap ออกแล้วถามทุกอย่างในจักรวาล | ใช้ materiality + dependency + scope เป็นตัวกรอง ไม่สร้าง checklist ที่ต้องถามครบทุกหมวด |
| “แนะนำ default” กลายเป็น agent อนุมัติเอง | แยกเสนอ/ตอบแล้ว/มอบหมาย; partial response ไม่ปิดข้ออื่น |
| Compact mode ซ่อน assumption | เก็บ semantic fields เดิมและ readiness check; ลดรูปแบบ ไม่ลดความครบ |
| ต้องเก็บ glossary ทุก task จนบวม | เขียนเฉพาะคำใหม่/กำกวมที่มีผลและจะใช้ต่อ ไม่สร้างไฟล์ถ้าไม่มีข้อมูล |
| เก็บ evidence มากจนกลายเป็น transcript dump | เก็บเฉพาะ decision/fact ที่ขับ approach และ pointer ไปต้นทาง |
| ต่อคำถามหลัง critique แล้ว agentเรียก reviewerวน | รักษาหนึ่ง critic invocation; follow-up อยู่ใน discovery ของ Lead |
| แก้ lint แล้วพยายามตรวจความหมายด้วย regex | Marker lint เท่านั้น; semantic failures อยู่ใน self-review/behavioral cases |
| Tests เพิ่มแต่ยังพิสูจน์แค่มีข้อความ | แสดงชนิด evidence ทุกครั้ง และแยก protocol ที่ยังไม่รันจากผลจริง |
| แก้ไฟล์ source แล้ว installed copy เก่า | Render ตรวจ artifacts; การ install/release เป็นงานอีกขั้นตาม authorization |

## 14. รูปแบบรายงานจาก session ที่ implement

ให้สรุปสั้น ๆ พร้อม evidence pointers:

1. เปลี่ยน behavior อะไร พร้อม before/after ตัวอย่างหนึ่งคู่
2. ไฟล์ source/generated ที่เปลี่ยนและเหตุผล
3. Tests/behavioral cases ที่รันจริง พร้อม PASS/SKIP/FAIL/NOT RUN
4. ผลเทียบแต่ละ metric ที่วัดได้ และ UNKNOWN ที่ยังไม่มีข้อมูล
5. ข้อจำกัด/งานที่ยังเหลือ/สถานะ branch โดยไม่อ้างว่า release แล้วถ้ายังไม่ได้ทำ

## 15. Kickoff สำหรับ session ถัดไป

ส่งข้อความนี้พร้อมไฟล์:

```text
ช่วย implement การปรับ write-spec ตามเอกสาร
/Users/nuttaruj/Project/rolepod/docs/rolepod/handoffs/write-spec-improvement-2026-09-05.md

เริ่มจากตรวจ HEAD, dirty files และคำสั่ง repo ปัจจุบันก่อน
ข้อสรุปที่ตกลงแล้วคือเลิกจำกัดจำนวน discovery questions และใช้ความครบของ
material decisions เป็นเกณฑ์จบ โดยไม่ถามซ้ำหรือถาม facts ที่ค้นเองได้

ใช้ข้อเสนอใน handoff เป็นฐาน ปรับ source เดิมและ tests ให้เล็กที่สุด
อย่าเพิ่ม skills/phases/config/dependencies หรือขยายขอบเขตไป redesign framework
รักษา approval ที่มีผลจริงและ cross-family opt-in เดิม
ถ้าไฟล์ต่างจาก baseline ให้ตรวจและปรับแผนเฉพาะส่วน ไม่ย้อนถามเรื่องที่ตกลงแล้ว

ถ้ามี concurrent session ให้แยก worktree ก่อนแก้ shared files
รัน focused tests, render และ checks ที่เกี่ยวข้อง แล้วทำ behavioral verification
ด้วยวิธีที่ harness รองรับจริง บันทึกสิ่งที่ยังวัดไม่ได้ตามตรง
ไม่ claim ว่าเหนือ Matt ทุกมิติโดยไม่มีผลวัด และไม่ push/merge/release/install
จนกว่าจะมีคำสั่งอนุมัติการกระทำนั้น
```

## 16. Primary references

บทความที่ผู้ใช้ส่งมา — อ่านวันที่ 2026-09-05:

- [AI Hero: grill-me](https://www.aihero.dev/skills-grill-me)
- [AI Hero: grill-with-docs](https://www.aihero.dev/skills-grill-with-docs)
- [AI Hero: research](https://www.aihero.dev/skills-research)
- [AI Hero: to-spec](https://www.aihero.dev/skills-to-spec)
- [AI Hero: to-tickets](https://www.aihero.dev/skills-to-tickets)
- [AI Hero: wayfinder](https://www.aihero.dev/skills-wayfinder)

Matt source snapshot ที่ pin สำหรับการทำซ้ำ:

- [Commit 3cca18b](https://github.com/mattpocock/skills/commit/3cca18b368ae95cdbdebbff572ccafa662551015)
- [grill-me wrapper](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/productivity/grill-me/SKILL.md)
- [grilling protocol](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/productivity/grilling/SKILL.md)
- [grill-with-docs wrapper](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/grill-with-docs/SKILL.md)
- [domain-modeling](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/domain-modeling/SKILL.md)
- [research](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/research/SKILL.md)
- [to-spec](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/to-spec/SKILL.md)
- [to-tickets](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/to-tickets/SKILL.md)
- [wayfinder](https://github.com/mattpocock/skills/blob/3cca18b368ae95cdbdebbff572ccafa662551015/skills/engineering/wayfinder/SKILL.md)

Local line numbers ใน handoff อ้าง baseline `354e020` และอาจเลื่อนหลังแก้ Path ชี้ workspace ที่ใช้ audit ถ้า session ถัดไปอยู่ worktree อื่น ให้ใช้ path ภายใน repo เดียวกันที่ checkout นั้น ห้ามแก้ checkout หลักตาม absolute link โดยไม่ตรวจตำแหน่งทำงาน
