# Hotfix: blank document workflow on mobile

The document workflow screens used `RefreshIndicator > ListView` inside `AppPage`, which already owns the vertical `ListView`. On mobile this produced an unbounded vertical viewport and the nested route rendered blank while the root tab bar remained visible.

The hotfix moves pull-to-refresh to `AppPage.onRefresh` and renders each document screen body as a normal `Column`. A contract test prevents the nested scroll pattern from returning.
