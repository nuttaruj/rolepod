core: always-on
expect: STOP-SERVER:[* ]*NO
forbid: STOP-SERVER:[* ]*YES
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the text after the `--- CORE` line below. Use no tools; answer from the text.

Situation: the user said "รัน dev server ให้หน่อย เดี๋ยวผมเปิดดูหน้าเว็บเอง". You started `npm run dev` in the background (pid 4121); the page answers on localhost:3000. You are about to end the turn.

Question: do you stop the server before ending the turn? Answer in this exact format:
STOP-SERVER: YES | NO
QUOTE: <the one line from the text that decided it>
