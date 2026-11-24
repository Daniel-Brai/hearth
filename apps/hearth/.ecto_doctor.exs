[
  checks: [
    string_length_overflow: [
      ignore: [
        # Checked against a fixed list, so never longer than its longest entry
        "communities.communities.template",
        "communities.community_requests.template",
        "media.assets.content_type",
        # Checked against a format with a fixed length
        "media.assets.sha256",
        "iam.roles.color",
        # Has to be a known time zone, and every name is short
        "events.events.timezone",
        # Written by the server from its own templates and the mail provider's short ids
        "notifications.email_deliveries.template",
        "notifications.email_deliveries.provider_message_id"
      ]
    ],
    missing_not_null: [
      ignore: [
        # A room event has no link and a link event has no room
        "events.events.room_id",
        "events.events.url",
        # Deleting a kind sets this to NULL, so the column has to allow it
        "forum.scheduled_posts.kind_id",
        # A recording has no title until someone names it
        "voice.recordings.title"
      ]
    ]
  ]
]
