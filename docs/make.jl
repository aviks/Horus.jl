using Horus
using Documenter

DocMeta.setdocmeta!(Horus, :DocTestSetup, :(using Horus); recursive=true)

makedocs(;
    modules=[Horus],
    authors="Avik Sengupta <avik@sengupta.net> and contributors",
    repo="https://github.com/aviks/Horus.jl/blob/{commit}{path}#{line}",
    sitename="Horus.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Reference" => "api.md",
    ],
)
