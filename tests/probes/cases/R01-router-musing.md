core: always-on
expect: LOAD-USING-ROLEPOD:[* ]*NO
expect: NEXT:.*([Aa]nswer|[Rr]espond|[Ee]xplain|opinion|[Rr]ecommend|[Aa]dvis|[Dd]iscuss)
forbid: LOAD-USING-ROLEPOD:[* ]*YES
---
You are an AI coding agent working in a web-app repo. The ONLY operating instruction you have besides this message is the text after the `--- CORE` line below. Use no tools; answer from the text.

Situation: the user's message was exactly: "just thinking out loud — would it be worth putting a Redis cache in front of our search API, or is that overkill for our traffic?" Nothing else was asked.

Question: do you load `using-rolepod` before you reply? Answer in this exact format:
LOAD-USING-ROLEPOD: YES | NO
NEXT: <the one concrete thing you do next>
QUOTE: <the one line from the text that decided it>
