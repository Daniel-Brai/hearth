import Config

# admins (instance admins only) or request (anyone asks and an admin decides) or anyone
config :hearth, Hearth.Communities, creation: {:system, "COMMUNITY_CREATION", "admins"}
