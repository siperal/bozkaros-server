Commercial Considerations

A few practical points for selling to enterprises:

    Clearly state the upstream in your documentation: "MyDistro Server is built on open source components including the Rocky Linux build infrastructure." You do not need to hide the lineage — you just cannot brand it as Rocky.

    Offer your own update repo: Your customers should subscribe to mycompany.repo, not dl.rockylinux.org directly. Mirror Rocky's repos, sign packages with your own GPG key, and push through your own update channel. This is also critical for your SLA/support story.

    Your GPG signing key replaces Rocky's in mydistro-release. Generate it with gpg --gen-key, export it, and reference it in your release RPM's %post.

    Support differentiation: The reason CIQ and others successfully sell Rocky-based products is that the value is in the support contract, hardened image, and certifications (like CIS Level 1/2, STIG) — not just the bits. Your DevSecOps background is a real differentiator here.


# TODO
    - TODO replace RHEL with Rocky, too
    - https://bozkaros.siperal.com/issues goes to Github issues
    