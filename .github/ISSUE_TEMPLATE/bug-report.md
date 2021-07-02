name: Bug Report
description: File a bug report
labels: [bug]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Also tell us, what did you expect to happen?
      placeholder: Tell us what you see!
    validations:
      required: true
  - type: dropdown
    id: version
    attributes:
      label: Version
      description: What version of fun-bots are you running?
      options:
        - < 1.5.x
        - 1.5.0.3
        - 1.6.x
        - 1.7.x
        - 2.0.0.x (Pre-releases)
    validations:
      required: true
