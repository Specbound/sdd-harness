---
name: x-article-publisher-skill
description: Use when converting a long-form article or blog post into an X/Twitter thread, or into a single promotional post pointing at the full article. Covers per-tweet character counting, thread numbering, and transition guidance.
source: "https://github.com/wshuyi/x-article-publisher-skill"
risk: safe
---

# X Article Publisher

## When to Use

Trigger when asked to:
- Turn an article/blog post into an X thread
- Write a single promotional tweet that links out to a full article
- Reformat existing long-form text to fit X's per-post character limit

## Output Modes

**Thread mode** (default for substantive articles): split the article into a numbered sequence of tweets, one idea per tweet.
**Single-post mode**: one tweet summarizing the article's hook + a link, for cases where the full argument doesn't need unpacking.

Ask which mode if the user's article length and request don't make it obvious (a 200-word note doesn't need a thread; a 2000-word essay usually does).

## Thread Construction Rules

1. **Character counting**: each tweet must fit X's limit (280 chars for standard accounts, count before adding the `N/` prefix).
2. **Numbering format**: prefix each tweet `N/` (e.g. `3/`) except optionally the first, which can lead with a hook instead.
3. **One idea per tweet** — don't cram two article paragraphs into one tweet just to reduce count.
4. **Transitions**: end tweets that continue a thought with a cliffhanger or "→" cue so readers keep tapping through; don't end mid-sentence unless the split is intentional.
5. **First tweet is the hook** — it determines whether anyone reads the rest. Lead with the article's most surprising claim or concrete result, not a generic "New post:" framing.
6. **Last tweet** includes the link to the full article (if one exists) and, optionally, a call to follow/reply.

## Quality Checklist (before returning the thread)

- [ ] Every tweet is under the character limit
- [ ] Numbering is sequential with no gaps or duplicates
- [ ] No tweet ends on an orphaned word or unfinished clause unintentionally
- [ ] The hook tweet stands alone as interesting even out of context (it's what gets quote-tweeted)
- [ ] Link (if any) appears exactly once, in the final tweet
