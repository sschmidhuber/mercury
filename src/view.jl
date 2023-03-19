app = dash()

active_nav = Dict("font-weight" => "bold")

app.layout = html_div() do
    html_header([
        html_h1("Mercury"),
        html_hr(),
        html_nav("Download", id="nav-download", style=active_nav),
        html_nav("Upload", id="nav-upload"),
        html_nav("Usage", id="nav-usage"),
        html_hr()
    ]),
    html_div([
        html_h2("Data Assets"),
        html_p("no hidden files"),
        html_div([
            html_label("Search term / secret file ID: "),
            dcc_input(value="", type="text")
        ]),
        html_div(
            [
                html_div("Data Asset 1"),
                html_div("Data Asset 2")
            ]
        )
    ]),
    html_h2("Upload stuff...", hidden=true)
end

#callback!(app, Output("nav-download", style), Output("nav-upload", style))
# add callback! to hide/show different views (data assets, upload, usage)