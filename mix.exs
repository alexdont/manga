defmodule Manga.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Batteries-included paged comic reader for Phoenix — manga-style page/spread reading on fresco's pan-zoom canvas: double-page spreads, RTL/LTR direction, rotation, page overrides, and in-place chapter swaps. Builds on the manhwa package's reader core."
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
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
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
