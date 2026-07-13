defmodule Manga.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Batteries-included paged comic reader for Phoenix — manga-style page/spread reading with double-page pairing, RTL/LTR direction, rotation, smart crop, and per-page overrides, on top of fresco. Builds on the `manhwa` package for the shared reader core and long-strip mode, so one dep gives a complete reader with a per-series mode switch."
  @source_url "https://github.com/alexdont/manga"

  def project do
    [
      app: :manga,
      version: @version,
      description: @description,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:manhwa, "~> 0.1"},
      {:fresco, "~> 0.7 or ~> 0.8"},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "manga",
      maintainers: ["Alexander Don"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      name: "Manga",
      source_ref: "v#{@version}",
      source_url: @source_url,
      main: "Manga",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
