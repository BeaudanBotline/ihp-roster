module Web.Controller.Exports where

import Application.Helper.Export
import Data.Time.Calendar (addDays)
import Network.HTTP.Types.Header (hContentDisposition, hContentType)
import Network.HTTP.Types.Status (status200)
import Network.Wai (responseLBS)
import Web.Controller.Prelude
import Web.View.Exports.Index

instance Controller ExportsController where
    beforeAction = do
        ensureIsUser
        ensureCurrentVenue
        ensureProfileCompleted
        ensureAdminRole

    action ExportJobsAction = do
        exportJobs <- fetchCurrentVenueExportJobs
        today <- utctDay <$> getCurrentTime
        let defaultRangeEnd = today
        let defaultRangeStart = addDays (-6) today
        render IndexView { .. }

    action CreateExportJobAction = do
        let maybeRangeStart = paramOrNothing @Day "rangeStart"
        let maybeRangeEnd = paramOrNothing @Day "rangeEnd"

        case (maybeRangeStart, maybeRangeEnd) of
            (Just rangeStart, Just rangeEnd) | rangeStart <= rangeEnd -> do
                _ <- requestApprovedTimesheetsCsvExport rangeStart rangeEnd
                setSuccessMessage "Export generated"
                redirectTo ExportJobsAction
            _ -> do
                setErrorMessage "Choose a valid start and end date for the export range."
                redirectTo ExportJobsAction

    action DownloadExportJobAction { exportJobId } = do
        let downloadToken = param @UUID "token"
        exportJob <- authorizeExportDownload exportJobId downloadToken >>= recordExportDownload

        let fileName = fromMaybe "export.csv" exportJob.fileName
        let contentType = fromMaybe "text/csv; charset=utf-8" exportJob.contentType
        let fileContents = cs (fromMaybe "" exportJob.fileContents)
        let contentDisposition = "attachment; filename=\"" <> fileName <> "\""

        respondAndExit $
            responseLBS
                status200
                [ (hContentType, cs contentType)
                , (hContentDisposition, cs contentDisposition)
                ]
                fileContents
