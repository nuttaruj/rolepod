<!-- Load when a test passes but you are not sure the assertion is strong. -->

A passing test with a weak assertion is a false green — it stays green even
when the code is wrong. LLM-written tests carry this defect often enough that
a green bar is not, by itself, proof.

## The flip test
Mentally flip the assertion: `==` to `!=`, `true` to `false`, present to
absent. If the test would STILL pass with the bug present, the assertion is
too weak — tighten it before trusting the green.

## Weak vs strong

| Change | Weak (false green) | Strong |
|--------|--------------------|--------|
| Returns a value | `assert result is not None` | `assert result == 42` |
| Builds a list | `assert len(rows) > 0` | `assert len(rows) == 3` |
| Sets a field | `assert user.status` | `assert user.status == "active"` |
| Calls an API | `assert response` | `assert response.code == 200 and body["id"]` |
| Raises an error | `assert raised` | `assert raised is ValidationError` + the message |
| Side effect | `assert mailer.called` | `assert mailer.called_with(to: user.email)` |

## Rule
Assert the EXACT expected value, state, or side effect — not merely that
something non-empty, non-null, or truthy happened.
