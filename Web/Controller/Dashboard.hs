module Web.Controller.Dashboard where

import Web.Controller.Prelude
import Web.View.Dashboard.Index

instance Controller DashboardController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted

    action DashboardAction = do
        render IndexView
