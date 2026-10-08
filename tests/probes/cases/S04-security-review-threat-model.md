skill: security-review
expect: TRUST-BOUNDARY:.*(webhook|/hooks|payload|body|request)
expect: ASSET:.*(order|status|payment|refund|account)
expect: STRIDE:[* ]*YES
expect: TRUST-RULE:.*wrote
forbid: STRIDE:[* ]*NO
---
You are an AI coding agent. The ONLY operating instruction you have besides this message is the skill text after the `--- SKILL ---` line below. Use no tools; answer from the text.

Situation: you are dispatched at depth: full on an R4 diff that adds `POST /hooks/billing`. The handler reads `order_id` and `status` from the JSON body and writes `orders.status`; it checks no signature and no caller identity. Nothing else in the diff touches security.

Question: what do you build before you read the diff line by line? Answer in this exact format:
TRUST-BOUNDARY: <where untrusted data enters, one line>
ASSET: <what an attacker reaches through it, one line>
STRIDE: YES | NO   (do you walk spoofing, tampering, repudiation, information disclosure, denial of service and elevation of privilege at each boundary?)
TRUST-RULE: <the one line from the skill that says whose word a value carries>
