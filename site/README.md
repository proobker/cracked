# Static website

index.html is the landing page; privacy.html and terms.html are legal pages.
style.css supplies styling; img holds images. .gdignore keeps site content out
of Godot asset importing.

tools/deploy_site.sh copies this folder to gh-pages and pushes. Download
artifacts live on GitHub releases. Read [tools](../tools/README.md) before publishing.

Keep release claims consistent with [release.md](../release.md). Planned content
must remain marked upcoming until shipped. Recheck privacy text when adding
saved XP/coin fields; the feature plan is not itself a policy review.

Check links, downloads, images and narrow-screen layout before deployment.
This README does not deploy anything.
