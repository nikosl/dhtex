get_colour = fn ->
  case System.get_env("MIX_ENV") do
    nil -> :white
    "dev" -> :green
    "test" -> :yellow
    _ -> :red
  end
end

IO.puts(
  IO.ANSI.magenta_background() <>
    IO.ANSI.white() <> " ❄❄❄ Mordor \u2694\uFE0F ❄❄❄ " <> IO.ANSI.reset()
)

Application.put_env(:elixir, :ansi_enabled, true)

IEx.configure(
  colors: [
    syntax_colors: [
      atom: :cyan,
      boolean: :magenta,
      charlist: :yellow,
      nil: :magenta,
      number: :yellow,
      string: :green,
      tuple: :magenta,
      map: :cyan
    ],
    eval_result: [:green, :bright],
    eval_error: [[:red, :bright, "\u{1F480} Error ..!!"]],
    eval_info: [:yellow, :bright]
  ],
  default_prompt:
    [
      get_colour.(),
      "%prefix",
      :white,
      "|",
      :blue,
      "%counter",
      :white,
      "|",
      :magenta,
      # :red,
      # "▶",
      # :white,
      # "▶▶",
      "|>",
      :reset
    ]
    |> IO.ANSI.format()
    |> IO.chardata_to_string(),
  alive_prompt:
    [
      get_colour.(),
      "%prefix",
      "|>",
      "%node",
      :white,
      "|",
      :blue,
      "%counter",
      :white,
      "|",
      :magenta,
      # :red,
      # "▶",
      # :white,
      # "▶▶",
      "|>",
      :reset
    ]
    |> IO.ANSI.format()
    |> IO.chardata_to_string()
)

Mix.ensure_application!(:observer)

