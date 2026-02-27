module Application.Helper.Controller where

import Generated.Types
import IHP.ControllerPrelude

-- Here you can add functions which are available in all your controllers

fetchVenueConfig :: (?modelContext :: ModelContext) => IO VenueConfig
fetchVenueConfig = query @VenueConfig |> fetchOne
