# Philosophy

## The Two Camps Problem

When it comes to using Linux, there are typically two distinct groups of people.

### Camp One: [Ricers](https://reddit.com/r/unixporn)

(Aesthetics = 999/10. Reliability = 1/10)

Usually younger creatives, students, or hobbyists, building insanely beautiful masterpieces, but endlessly replacing components, rebuilding configs every month, actually every week, some even days. And have ABSOLUTELY no problem bricking the daily driver on a Monday morning.

### Camp Two: [ThePrimeagen's setup](https://youtu.be/bdumjiHabhQ)

(Aesthetics = -1/10. Reliability = 10/10)

Brutally efficient workflows, fast terminals, muxed everywhere, keyboard-driven systems, extremely high throughput for professional work, but the machine itself often looks like an ancient (and hostile) screen from the 80s that no one wants to use. And CANNOT brick the daily driver on a Saturday night, let alone a Monday morning.

So, this project combines the best parts of both.

## Headless by Design

This is a headless setup too.

A normal Linux install is headed by default. Even `archinstall` these days is headed. You install Debian or Ubuntu, and it hands you a desktop, a login screen, a file manager, default apps, and a prebuilt user experience.

A headless machine is the exact opposite. You boot into a bare text console, and absolutely nothing exists until you build it. This project treats the operating system as a raw base substrate and constructs a custom user space entirely on top of it.

## Model

The mental model is stability over novelty. But also composability.

Built brick by brick on top of a raw Linux base, but each brick can be used separately on its own. This is closer to provisioning infrastructure than installing a rice, or having to accept everything an ISO provides.

Starting with a bare Debian machine, then layer the system upward through automated builders, configs, automated theming, standalone programs, and small systems that each do one job. Each piece has a job, and that job is tested through CI/CD into oblivion so what works today keeps working tomorrow.

You can adopt the full direction, or you can take only the parts you want. Use the theming engine without my Neovim. Use the greeter on another distro, etc.

Right now Debian is the base because it gives me a predictable substrate. Long term, the same idea can be carried to other distros: raw system first, scripted layers on top, reproducible user space after that.

## "If it ain't broke don't fix it"

Someone asked me the other day why I don't constantly chase every Hyprland release, config migration, and newer ecosystem around it.

Well, the current setup already works perfectly.

Pulling the latest compositor update should not risk dropping your machine into a TTY before a meeting, during travel, or mid flow state because an upstream package had a breaking change.

This project is built specifically to avoid that class of failure.

For example, Hyprland itself is built through a separate layer with pinned versions, automated builds, and CI/CD validation. Run after the initial [bootstrap](../.github/workflows/on-workflow-call-bootstrap.yml). This builder will also be open sourced.
