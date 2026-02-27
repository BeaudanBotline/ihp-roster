module Web.Controller.Dashboard where

import Web.Controller.Prelude
import Web.View.Dashboard.Index

instance Controller DashboardController where
    action DashboardAction = do
        ensureIsUser
        render IndexView
