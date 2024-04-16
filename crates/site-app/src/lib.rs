use leptos::*;
use leptos_meta::*;
use leptos_router::{Route, Router, Routes};

#[component]
pub fn App() -> impl IntoView {
    // Provides context that manages stylesheets, titles, meta tags, etc.
    provide_meta_context();

    view! {
      <Stylesheet id="leptos" href="/pkg/site.css"/>

      <Title text="A template app"/>
      <Html lang="en" />
      <Meta charset="utf-8"/>
      <Meta name="viewport" content="width=device-width, initial-scale=1"/>

      <Router>
        <Routes>
          <Route path="/" view=HomePage />
        </Routes>
      </Router>
    }
}

#[component]
pub fn HomePage() -> impl IntoView {
    view! {
      <p>"Hello, World!"</p>
    }
}
