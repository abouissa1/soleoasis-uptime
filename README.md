# Sole Oasis — external uptime monitor

Checks that [soleoasis.net](https://soleoasis.net) and its booking, staff and
API endpoints answer **from outside our own infrastructure**, every 15 minutes.

## Why this repository exists

There is already a watchdog, but it runs *on the production server* and reaches
the site by going out to the CDN and back in again. That has two blind spots:

1. **It cannot report its own death.** If the server goes down, so does the
   thing that would have told you.
2. **It measures a path no customer uses.** On 21 September 2026 that path
   failed completely for two hours while visitors were mostly fine — and
   earlier the same day the reverse was true. Neither matched what customers
   actually experienced.

This monitor runs on a GitHub runner: a different network, a different
continent, and nothing to do with our server. When the two disagree, the
disagreement is itself the useful signal.

## How you are told

A failed check **opens an issue**; a passing check **closes it**. GitHub emails
the repository owner for both, so you get one message when something breaks and
one when it recovers — not a new one every 15 minutes.

## Why this repository is public

Public repositories get unlimited free GitHub Actions minutes; private ones on
the free plan get 2,000 a month, which a 15-minute schedule would exhaust. So
this repository is public **and contains nothing that isn't already public** —
no keys, no server addresses, no application code. Just the three URLs anyone
can type into a browser.

## Checking it yourself

- **Actions → uptime → Run workflow** runs it on demand.
- Tick **simulate_failure** to point it at a deliberately broken URL and watch
  it raise a real alert. A monitor you have never seen go red is not a monitor
  you can trust.
- `./check.sh` runs the same script locally.
