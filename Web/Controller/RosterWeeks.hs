module Web.Controller.RosterWeeks where

import Application.Helper.Conflict
import Application.Helper.Controller
import Data.Coerce (coerce)
import Data.List (find, nub, sortBy)
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import qualified Data.Text as Text
import Data.Time (diffDays, getCurrentTime, utctDay)
import qualified Data.Time.Calendar as Calendar
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Data.Time.LocalTime (TimeOfDay)
import qualified Data.UUID as UUID
import Web.Controller.Prelude
import Web.View.RosterWeeks.Show

instance Controller RosterWeeksController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted

    action RosterWeeksAction = do
        -- Redirect to the current week's offset based on today's date
        now <- liftIO getCurrentTime
        venueConfig <- fetchVenueConfig

        let today = utctDay now
        let epoch = venueConfig.weekOffsetEpoch
        let daysSinceEpoch = diffDays today epoch
        let currentWeekOffset = fromIntegral (daysSinceEpoch `div` 7)

        redirectTo ShowRosterWeekAction { weekOffset = currentWeekOffset }

    action ShowRosterWeekAction { weekOffset } = autoRefresh do
        venueConfig <- fetchVenueConfig
        let epoch = venueConfig.weekOffsetEpoch
        let weekStartDate = Calendar.addDays (toInteger (weekOffset * 7)) epoch
        let weekEndDate = Calendar.addDays 6 weekStartDate

        -- Try to fetch the roster week from the database
        rosterWeekOrNothing <- query @RosterWeek
            |> filterWhere (#weekOffset, weekOffset)
            |> fetchOneOrNothing

        let isManager = hasRole ManagerRole
        let visibleRosterWeek = case rosterWeekOrNothing of
                Just rw -> if not rw.isLive && not isManager then Nothing else Just rw
                Nothing -> Nothing

        case visibleRosterWeek of
            Just rosterWeek -> do
                -- We found it, render the week view
                rosterDays <- query @RosterDay
                    |> filterWhere (#rosterWeekId, coerce rosterWeek.id)
                    |> orderBy #dayOffset
                    |> fetch

                -- Fetch all slots for these days
                allSlots <- query @RosterSlot
                    |> filterWhereIn (#rosterDayId, map (coerce . (.id)) rosterDays)
                    |> fetch

                -- Prefetch all staff for the dropdowns
                staffMembers <- query @Staff
                    |> filterWhere (#isActive, True)
                    |> orderBy #lastName
                    |> fetch

                -- Prefetch slot names for column mapping
                slotNames <- query @SlotName
                    |> filterWhere (#isActive, True)
                    |> fetch

                let orderedSlotNames = sortBy (comparing (slotNameOrder . (.name))) slotNames
                slotConflicts <- buildSlotConflicts weekStartDate rosterDays allSlots staffMembers

                render ShowView
                    { rosterWeek = Just rosterWeek
                    , rosterDays
                    , weekOffset
                    , weekStartDate
                    , weekEndDate
                    , staffMembers
                    , slotNames = orderedSlotNames
                    , allSlots
                    , slotConflicts
                    }
            Nothing -> do
                -- It doesn't exist yet, show the "Create" view/button
                render ShowView
                    { rosterWeek = Nothing
                    , rosterDays = []
                    , weekOffset
                    , weekStartDate
                    , weekEndDate
                    , staffMembers = []
                    , slotNames = []
                    , allSlots = []
                    , slotConflicts = []
                    }

    action CreateRosterWeekAction { weekOffset } = do
        ensureManagerRole

        -- Make sure it doesn't already exist
        existing <- query @RosterWeek |> filterWhere (#weekOffset, weekOffset) |> fetchOneOrNothing
        case existing of
            Just week -> do
                redirectTo ShowRosterWeekAction { weekOffset = week.weekOffset }
            Nothing -> do
                -- Create the roster week
                rosterWeek <- newRecord @RosterWeek
                    |> set #weekOffset weekOffset
                    |> set #isLive False
                    |> createRecord

                -- Create 7 roster days for the week
                forM_ [0 .. 6] \dayOffset -> do
                    newRecord @RosterDay
                        |> set #rosterWeekId (coerce rosterWeek.id)
                        |> set #dayOffset dayOffset
                        |> createRecord

                setSuccessMessage "Roster week created successfully"
                redirectTo ShowRosterWeekAction { weekOffset }

    action CopyRosterWeekAction { sourceWeekOffset, targetWeekOffset } = do
        ensureManagerRole

        -- Make sure target doesn't already exist
        existingTarget <- query @RosterWeek |> filterWhere (#weekOffset, targetWeekOffset) |> fetchOneOrNothing
        case existingTarget of
            Just week -> do
                setErrorMessage "Target week already exists."
                redirectTo ShowRosterWeekAction { weekOffset = targetWeekOffset }
            Nothing -> do
                sourceWeekOrNothing <- query @RosterWeek |> filterWhere (#weekOffset, sourceWeekOffset) |> fetchOneOrNothing
                case sourceWeekOrNothing of
                    Nothing -> do
                        setErrorMessage "Source week not found. Cannot copy."
                        redirectTo ShowRosterWeekAction { weekOffset = targetWeekOffset }
                    Just sourceWeek -> do
                        -- Create the target roster week
                        targetWeek <- newRecord @RosterWeek
                            |> set #weekOffset targetWeekOffset
                            |> set #isLive False
                            |> createRecord

                        sourceDays <- query @RosterDay |> filterWhere (#rosterWeekId, coerce sourceWeek.id) |> fetch

                        -- Create 7 roster days for the week
                        forM_ [0 .. 6] \dayOffset -> do
                            targetDay <- newRecord @RosterDay
                                |> set #rosterWeekId (coerce targetWeek.id)
                                |> set #dayOffset dayOffset
                                |> createRecord

                            -- Find corresponding source day and copy slots
                            let maybeSourceDay = find (\d -> d.dayOffset == dayOffset) sourceDays
                            case maybeSourceDay of
                                Just sourceDay -> do
                                    sourceSlots <- query @RosterSlot |> filterWhere (#rosterDayId, coerce sourceDay.id) |> fetch
                                    forM_ sourceSlots \slot -> do
                                        newRecord @RosterSlot
                                            |> set #rosterDayId (coerce targetDay.id)
                                            |> set #staffId slot.staffId
                                            |> set #slotNameId slot.slotNameId
                                            |> set #rowIndex slot.rowIndex
                                            |> set #startTime slot.startTime
                                            |> set #durationMinutes slot.durationMinutes
                                            |> set #note slot.note
                                            |> createRecord
                                        pure ()
                                Nothing -> pure ()

                        setSuccessMessage "Roster week copied successfully."
                        redirectTo ShowRosterWeekAction { weekOffset = targetWeekOffset }

    action PublishRosterWeekAction { rosterWeekId } = do
        ensureManagerRole
        rosterWeek <- fetch rosterWeekId
        rosterWeek
            |> set #isLive True
            |> updateRecord

        setSuccessMessage "Roster week published successfully"
        redirectTo ShowRosterWeekAction { weekOffset = rosterWeek.weekOffset }

    action AddRosterRowAction { rosterDayId } = do
        ensureManagerRole

        -- Find the current max row index for this day
        existingSlots <- query @RosterSlot |> filterWhere (#rosterDayId, coerce rosterDayId) |> fetch
        let nextRowIndex = if null existingSlots then 0 else maximum (map (.rowIndex) existingSlots) + 1

        -- Get slot names for Early, Mid, Late
        slotNames <- query @SlotName |> filterWhere (#isActive, True) |> fetch
        let orderedSlotNames = sortBy (comparing (slotNameOrder . (.name))) slotNames

        -- Create a slot for each slot name (column)
        forM_ orderedSlotNames \slotName -> do
            newRecord @RosterSlot
                |> set #rosterDayId (coerce rosterDayId)
                |> set #slotNameId (coerce slotName.id)
                |> set #rowIndex nextRowIndex
                |> createRecord

        -- Use respondHtml for HTMX/AutoRefresh consistency
        respondHtml ""

    action DeleteRosterRowAction { rosterDayId, rowIndex } = do
        ensureManagerRole

        -- Delete all slots in this row for the day
        slotsToDelete <- query @RosterSlot
            |> filterWhere (#rosterDayId, coerce rosterDayId)
            |> filterWhere (#rowIndex, rowIndex)
            |> fetch

        deleteRecords slotsToDelete

        respondHtml ""

    action UpdateRosterSlotAction { rosterSlotId } = do
        ensureManagerRole

        rosterSlot <- fetch rosterSlotId

        -- Each edit posts the whole cell form via HTMX, so we can update atomically.
        let staffId = parseOptionalStaffId $ paramOrNothing @Text "staffId"
        let startTime = parseOptionalTime $ paramOrNothing @Text "startTime"
        let note = normalizeOptionalText $ paramOrNothing @Text "note"

        rosterSlot
            |> set #staffId staffId
            |> set #startTime startTime
            |> set #note note
            |> updateRecord

        respondHtml ""

slotNameOrder :: Text -> Int
slotNameOrder slotName =
    case Text.toLower slotName of
        "early" -> 0
        "mid"   -> 1
        "late"  -> 2
        _       -> 3

parseOptionalStaffId :: Maybe Text -> Maybe UUID.UUID
parseOptionalStaffId value = maybe Nothing UUID.fromText (normalizeOptionalText value)

parseOptionalTime :: Maybe Text -> Maybe TimeOfDay
parseOptionalTime value =
    case normalizeOptionalText value of
        Nothing -> Nothing
        Just valueText -> parseTimeM True defaultTimeLocale "%H:%M" (cs valueText)

normalizeOptionalText :: Maybe Text -> Maybe Text
normalizeOptionalText = \case
    Nothing -> Nothing
    Just value ->
        let trimmed = Text.strip value
         in if Text.null trimmed then Nothing else Just trimmed

buildSlotConflicts :: (?modelContext :: ModelContext) => Calendar.Day -> [RosterDay] -> [RosterSlot] -> [Staff] -> IO [(Id RosterSlot, [RosterConflict])]
buildSlotConflicts weekStartDate rosterDays allSlots staffMembers = do
    let assignedStaffIds = nub $ mapMaybe (.staffId) allSlots
    if null assignedStaffIds
        then pure []
        else do
            leaveRequests <- query @LeaveRequest
                |> filterWhereIn (#staffId, assignedStaffIds)
                |> fetch

            availabilities <- query @StaffAvailability
                |> filterWhereIn (#staffId, assignedStaffIds)
                |> fetch

            let dayById = map (\day -> (coerce day.id, day)) rosterDays
            let conflictsBySlot = mapMaybe (conflictsForSlot dayById leaveRequests availabilities) allSlots
            pure conflictsBySlot
    where
        conflictsForSlot dayById leaveRequests availabilities slot = do
            staffUuid <- slot.staffId
            day <- lookup slot.rosterDayId dayById
            let weekSlotsForStaff = filter (\candidate -> candidate.staffId == Just staffUuid) allSlots
            let daySlotsForStaff = filter (\candidate -> candidate.rosterDayId == slot.rosterDayId && candidate.staffId == Just staffUuid) allSlots
            let staffIdealShifts = (.idealShiftsPerWeek) =<< find (\staff -> coerce staff.id == staffUuid) staffMembers
            let leaveRequestsForStaff = filter (\leaveRequest -> leaveRequest.staffId == staffUuid) leaveRequests
            let availabilitiesForStaff = filter (\availability -> availability.staffId == staffUuid) availabilities
            let rosterDayDate = Calendar.addDays (toInteger day.dayOffset) weekStartDate
            let conflicts = evaluateConflicts ConflictContext
                    { slot
                    , weekSlots = weekSlotsForStaff
                    , daySlots = daySlotsForStaff
                    , leaveRequests = leaveRequestsForStaff
                    , availabilities = availabilitiesForStaff
                    , rosterDayDate
                    , staffIdealShifts
                    }
            if null conflicts
                then Nothing
                else Just (slot.id, conflicts)
