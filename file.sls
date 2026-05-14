{#start_schema
{
  "description": {
    "en": "MY Managing files and directories.",
    "ru": "MY Управление файлами и каталогами."
  },
  "json_schema": {
    "type": "object",
    "title": "MY -  System - Files and directories",
    "additionalProperties": false,
    "required": [
      "kwargs"
    ],
    "properties": {
      "kwargs": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "pillar"
        ],
        "properties": {
          "pillar": {
            "type": "object",
            "required": [
              "action",
              "name"
            ],
            "properties": {
              "action": {
                "type": "string",
                "default": "append",
                "oneOf": [
                  {
                    "title": "MY Append lines",
                    "const": "append"
                  },
                  {
                    "title": "Change file permissions",
                    "const": "permissions"
                  },
                  {
                    "title": "Comment out file",
                    "const": "comment"
                  },
                  {
                    "title": "Copy file",
                    "const": "copy"
                  },
                  {
                    "title": "Create symlink",
                    "const": "symlink"
                  },
                  {
                    "title": "Delete line",
                    "const": "delete"
                  },
                  {
                    "title": "Edit file based on key-value pairs",
                    "const": "keyvalue"
                  },
                  {
                    "title": "Get file or directory",
                    "const": "get"
                  },
                  {
                    "title": "Remove file or directory",
                    "const": "absent"
                  },
                  {
                    "title": "Replace line",
                    "const": "replace"
                  },
                  {
                    "title": "Uncomment file",
                    "const": "uncomment"
                  },
                  {
                    "title": "Write contents to file",
                    "const": "write"
                  }
                ]
              },
              "name": {
                "type": "string",
                "pattern": "^(/|[a-zA-Z]:\\\\).+"
              }
            },
            "allOf": [
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "append"
                    }
                  }
                },
                "then": {
                  "properties": {
                    "contents": {
                      "title": "The text to be appended, which can be a single string or a list of strings",
                      "type": "string"
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "get"
                    }
                  }
                },
                "then": {
                  "required": [
                    "source",
                    "source_type"
                  ],
                  "properties": {
                    "source_type": {
                      "type": "string",
                      "title": "Type",
                      "default": "file",
                      "oneOf": [
                        {
                          "title": "Single file",
                          "const": "file"
                        },
                        {
                          "title": "Directory",
                          "const": "directory"
                        }
                      ]
                    },
                    "source": {
                      "type": "string",
                      "title": "Source",
                      "description": "The source file or directory to download to the client.",
                      "examples": [
                        "salt://files/archive.tar.gz",
                        "salt://files/wallpapers"
                      ]
                    }
                  },
                  "if": {
                    "properties": {
                      "source_type": {
                        "const": "directory"
                      }
                    }
                  },
                  "then": {
                    "properties": {
                      "source": {
                        "pattern": "^salt://[^\\0\\r\\n]+$"
                      }
                    }
                  },
                  "else": {
                    "properties": {
                      "source": {
                        "pattern": "^(salt|http|https)://[^\\0\\r\\n]+$"
                      }
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "permissions"
                    }
                  }
                },
                "then": {
                  "properties": {
                    "mode": {
                      "title": "The permissions to set on this file",
                      "type": "string",
                      "pattern": "^[0-7]{3,4}$"
                    },
                    "user": {
                      "title": "The user to own the file",
                      "type": "string"
                    },
                    "group": {
                      "title": "The group ownership set for the file",
                      "type": "string"
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "comment"
                    }
                  }
                },
                "then": {
                  "required": [
                    "match"
                  ],
                  "properties": {
                    "match": {
                      "title": "A regular expression used to find the lines that are to be out commented",
                      "type": "string"
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "copy"
                    }
                  }
                },
                "then": {
                  "required": [
                    "source"
                  ],
                  "properties": {
                    "source": {
                      "title": "The location of the source file on the file system",
                      "type": "string",
                      "pattern": "^(/|[a-zA-Z]:\\\\).+"
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "symlink"
                    }
                  }
                },
                "then": {
                  "required": [
                    "target"
                  ],
                  "properties": {
                    "target": {
                      "title": "The location that the symlink points to",
                      "type": "string",
                      "pattern": "^(/|[a-zA-Z]:\\\\).+"
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "delete"
                    }
                  }
                },
                "then": {
                  "properties": {
                    "match": {
                      "title": "Match the target line for an action by a fragment of a string or regular expression",
                      "type": "string"
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "keyvalue"
                    }
                  }
                },
                "then": {
                  "required": [
                    "contents"
                  ],
                  "properties": {
                    "contents": {
                      "title": "List of key-value pairs strings to search for and ensure values",
                      "description": "Use the strings `key=value` with the necessary separator",
                      "type": "string"
                    },
                    "separator": {
                      "title": "Separator in the edited file which separates key from value",
                      "description": "Default is `=`",
                      "type": "string"
                    },
                    "count": {
                      "title": "Number of occurrences to allow (and correct)",
                      "description": "Default is 1. Set to -1 to replace all, or set to 0 to remove all lines with this key regardsless of its value.",
                      "type": "integer",
                      "minimum": -1
                    },
                    "chars": {
                      "title": "Disregard and remove supplied leading characters when finding keys",
                      "description": "Default is `#`. When set to None, lines that are commented out are left for what they are.",
                      "type": "string"
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "replace"
                    }
                  }
                },
                "then": {
                  "required": [
                    "match",
                    "repl"
                  ],
                  "properties": {
                    "match": {
                      "title": "A regular expression, to be matched",
                      "type": "string"
                    },
                    "repl": {
                      "title": "The repl text",
                      "type": "string"
                    },
                    "count": {
                      "title": "Maximum number of pattern occurrences to be replaced",
                      "description": "Default is 1. If count is a positive integer n, no more than n occurrences will be replaced, otherwise all occurrences will be replaced.",
                      "type": "integer",
                      "minimum": 0
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "uncomment"
                    }
                  }
                },
                "then": {
                  "required": [
                    "match"
                  ],
                  "properties": {
                    "match": {
                      "title": "A regular expression used to find the lines that are to be uncommented",
                      "type": "string"
                    }
                  }
                }
              },
              {
                "if": {
                  "properties": {
                    "action": {
                      "const": "write"
                    }
                  }
                },
                "then": {
                  "properties": {
                    "contents": {
                      "title": "Specify the contents of the file",
                      "type": "string"
                    }
                  }
                }
              }
            ]
          }
        }
      }
    }
  },
  "ui_schema": {
    "kwargs": {
      "ui:title": "",
      "pillar": {
        "ui:title": "",
        "ui:order": [
          "action",
          "name",
          "*"
        ],
        "action": {
          "ui:title": "Choose what to do with the file",
          "ui:widget": "select"
        },
        "name": {
          "ui:title": "Name",
          "ui:description": "The location of the object on the local file system.",
          "ui:autofocus": true
        },
        "contents": {
          "ui:widget": "textarea",
          "ui:enableMarkdownInDescription": true,
          "ui:options": {
            "rows": 10
          }
        },
        "separator": {
          "ui:enableMarkdownInDescription": true
        },
        "chars": {
          "ui:enableMarkdownInDescription": true
        },
        "mode": {
          "ui:placeholder": "Example: 644, 0775 or 4664"
        }
      }
    }
  }
}
end_schema#}
{% set action      = pillar.action %}
{% set name        = pillar.name %}
{% set contents    = pillar.get('contents', '') %}
{% set match       = pillar.get('match', '') %}
{% set repl        = pillar.repl %}
{% set count       = pillar.get('count', 1) | int %}
{% set separator   = pillar.get('separator', '=') %}
{% set chars       = pillar.get('chars', '#') %}
{% set target      = pillar.target %}
{% set source      = pillar.source %}
{% set mode        = pillar.get('mode', '') %}
{% set user        = pillar.get('user', '') %}
{% set group       = pillar.get('group', '') %}
{% set source_type = pillar.source_type %}

{# Fully working Jinja SLS fragment for file actions. Place inside your SLS file. #}
{% set action = pillar.get('action') %}
{% set name = pillar.get('name') %}
{% set contents = pillar.get('contents', '') %}
{% set match = pillar.get('match', '') %}
{% set repl = pillar.get('repl', '') %}
{% set count = pillar.get('count', 1) | int %}
{% set separator = pillar.get('separator', '=') %}
{% set chars = pillar.get('chars', '#') %}
{% set target = pillar.get('target', '') %}
{% set source = pillar.get('source', '') %}
{% set mode = pillar.get('mode', '') %}
{% set user = pillar.get('user', '') %}
{% set group = pillar.get('group', '') %}
{% set source_type = pillar.get('source_type', 'file') %}

{% if action %}
perform_action_{{ name | replace('/', '_') | replace('.', '_') | default('unknown') }}:
  test.show_notification:
    - text: "Perform an action with the file: {{ action }}"
{% endif %}

{% if action is defined %}
Perform an action with the file:
{% if action == 'append' %}
{{ name }}:
  file.append:
    - text:
{% if contents is string and contents.strip() == '' %}
      []
{% else %}
{# Safe: either render whole block as one multiline element (keep exact YAML), or render per-line.
   Use multiline-block approach to preserve internal indentation of YAML content. Uncomment chosen variant. #}

{# Variant A — insert entire contents as one multiline block (exact copy). Good when you must preserve YAML indentation. #}
    - text:
      - |-
{{ contents | trim | indent(8) }}
    - makedirs: True
    - backup: True

{# Variant B — per-line insertion (safer if you don't rely on exact leading spaces).
    Uncomment and use instead of Variant A by removing Variant A above. #}
{# 
    - text:
{% for line in contents.splitlines() %}
      - {{ line | replace('"', '\\"') | yaml_dquote }}
{% endfor %}
    - makedirs: True
    - backup: True
#}
{% elif action == 'permissions' %}
{{ name }}:
  file.managed:
    - name: {{ name }}
    - create: False
    - keep_source: False
    - mode: '{{ mode }}'
    - user: {{ user }}
    - group: {{ group }}
{% elif action == 'comment' %}
{{ name }}:
  file.comment:
    - name: {{ name }}
    - regex: '{{ match }}'
    - ignore_missing: True
{% elif action == 'copy' %}
{{ name }}:
  file.copy:
    - name: {{ name }}
    - source: {{ source }}
    - makedirs: True
    - force: True
{% elif action == 'symlink' %}
{{ name }}:
  file.symlink:
    - name: {{ name }}
    - target: {{ target }}
    - makedirs: True
    - force: True
{% elif action == 'delete' %}
{{ name }}:
  file.line:
    - name: {{ name }}
    - mode: delete
    - match: '{{ match }}'
{% elif action == 'absent' %}
{{ name }}:
  file.absent:
    - name: {{ name }}
{% elif action == 'keyvalue' %}
{{ name }}:
  file.keyvalue:
    - name: {{ name }}
    - key_values:
{% for content in contents.split('\n') %}
      - {{ content.split(separator, 1) | map('trim') | map('quote') | join(': ') }}
{% endfor %}
    - separator: '{{ separator }}'
    - chars: '{{ chars }}'
    - count: {{ count }}
    - key_ignore_case: True
    - append_if_not_found: True
{% elif action == 'replace' %}
{{ name }}:
  file.replace:
    - name: {{ name }}
    - pattern: '{{ match }}'
    - repl: '{{ repl }}'
    - count: {{ count }}
    - backup: False
{% elif action == 'uncomment' %}
{{ name }}:
  file.uncomment:
    - name: {{ name }}
    - regex: '{{ match }}'
{% elif action == 'write' %}
{{ name }}:
  file.managed:
    - name: {{ name }}
    - contents: |
{{ contents | indent(6) }}
    - keep_source: False
    - makedirs: True
{% elif action == 'get' %}
{{ name }}:
  file.{{ 'recurse' if source_type == 'directory' else 'managed' }}:
    - name: {{ name }}
    - source: {{ source }}
    - keep_source: False
    - makedirs: True
{% endif %}
{% endif %}
