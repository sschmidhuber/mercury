app = dash()

app.layout = html_div() do
    html_header([
        html_h1("Mercury"),
        html_p("Upload (not implemented)"),
        html_p("Statistics (not implemented)"),
        html_p("About (not implemented)")
    ]),
    html_div([
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
    ])
end