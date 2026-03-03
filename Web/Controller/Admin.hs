module Web.Controller.Admin where

import Application.Helper.Pay
import qualified Data.Text as Text
import Web.Controller.Prelude
import Web.View.Admin.Index

instance Controller AdminController where
    beforeAction = do
        ensureIsUser
        ensureCurrentVenue
        ensureProfileCompleted
        ensureAdminRole

    action AdminAction = do
        recentSnapshots <- fetchCurrentVenuePayConfigSnapshots
        payLevels <- fetchCurrentVenuePayLevels
        shiftTypes <- fetchCurrentVenueShiftTypes
        slotNames <- fetchCurrentVenueSlotNames
        dayNames <- fetchCurrentVenueDayNames
        let latestSnapshot = listToMaybe recentSnapshots
        render IndexView { .. }

    action CreatePayConfigSnapshotAction = do
        snapshot <- createCurrentVenuePayConfigSnapshot
        setSuccessMessage ("Saved pay/config snapshot " <> snapshot.versionLabel)
        redirectTo AdminAction

    action CreatePayLevelAction = do
        maybeName <- parseRequiredName "name" "Pay level name is required."
        case maybeName of
            Nothing -> redirectTo AdminAction
            Just name -> do
                let isActive = parseIsActiveParam
                _ <- newRecord @PayLevel
                    |> set #venueId (unpackId currentVenueId)
                    |> set #name name
                    |> set #isActive isActive
                    |> createRecord
                setSuccessMessage "Pay level added"
                redirectTo AdminAction

    action UpdatePayLevelAction { payLevelId } = do
        payLevel <- fetch payLevelId
        ensureRecordInCurrentVenue payLevel.venueId
        maybeName <- parseRequiredName "name" "Pay level name is required."
        case maybeName of
            Nothing -> redirectTo AdminAction
            Just name -> do
                let isActive = parseIsActiveParam
                _ <- payLevel
                    |> set #name name
                    |> set #isActive isActive
                    |> updateRecord
                setSuccessMessage "Pay level updated"
                redirectTo AdminAction

    action CreateShiftTypeAction = do
        payLevels <- fetchCurrentVenuePayLevels
        if null payLevels
            then do
                setErrorMessage "Add at least one pay level before creating a shift type."
                redirectTo AdminAction
            else do
                maybeName <- parseRequiredName "name" "Shift type name is required."
                case maybeName of
                    Nothing -> redirectTo AdminAction
                    Just name -> do
                        let isActive = parseIsActiveParam
                        maybePayLevel <- parseDefaultPayLevelId
                        case maybePayLevel of
                            Nothing -> redirectTo AdminAction
                            Just defaultPayLevelId -> do
                                _ <- newRecord @ShiftType
                                    |> set #venueId (unpackId currentVenueId)
                                    |> set #name name
                                    |> set #defaultPayLevelId (unpackId defaultPayLevelId)
                                    |> set #isActive isActive
                                    |> createRecord
                                setSuccessMessage "Shift type added"
                                redirectTo AdminAction

    action UpdateShiftTypeAction { shiftTypeId } = do
        shiftType <- fetch shiftTypeId
        ensureRecordInCurrentVenue shiftType.venueId
        maybeName <- parseRequiredName "name" "Shift type name is required."
        case maybeName of
            Nothing -> redirectTo AdminAction
            Just name -> do
                let isActive = parseIsActiveParam
                maybePayLevel <- parseDefaultPayLevelId
                case maybePayLevel of
                    Nothing -> redirectTo AdminAction
                    Just defaultPayLevelId -> do
                        _ <- shiftType
                            |> set #name name
                            |> set #defaultPayLevelId (unpackId defaultPayLevelId)
                            |> set #isActive isActive
                            |> updateRecord
                        setSuccessMessage "Shift type updated"
                        redirectTo AdminAction

    action CreateSlotNameAction = do
        maybeName <- parseRequiredName "name" "Slot name is required."
        case maybeName of
            Nothing -> redirectTo AdminAction
            Just name -> do
                let isActive = parseIsActiveParam
                _ <- newRecord @SlotName
                    |> set #venueId (unpackId currentVenueId)
                    |> set #name name
                    |> set #isActive isActive
                    |> createRecord
                setSuccessMessage "Slot name added"
                redirectTo AdminAction

    action UpdateSlotNameAction { slotNameId } = do
        slotName <- fetch slotNameId
        ensureRecordInCurrentVenue slotName.venueId
        maybeName <- parseRequiredName "name" "Slot name is required."
        case maybeName of
            Nothing -> redirectTo AdminAction
            Just name -> do
                let isActive = parseIsActiveParam
                _ <- slotName
                    |> set #name name
                    |> set #isActive isActive
                    |> updateRecord
                setSuccessMessage "Slot name updated"
                redirectTo AdminAction

    action CreateDayNameAction = do
        maybeDayNameParams <- parseDayNameParams Nothing
        case maybeDayNameParams of
            Nothing -> redirectTo AdminAction
            Just (weekdayIndex, name, isActive) -> do
                _ <- newRecord @DayName
                    |> set #venueId (unpackId currentVenueId)
                    |> set #weekdayIndex weekdayIndex
                    |> set #name name
                    |> set #isActive isActive
                    |> createRecord
                setSuccessMessage "Day name added"
                redirectTo AdminAction

    action UpdateDayNameAction { dayNameId } = do
        dayName <- fetch dayNameId
        ensureRecordInCurrentVenue dayName.venueId
        maybeDayNameParams <- parseDayNameParams (Just dayName)
        case maybeDayNameParams of
            Nothing -> redirectTo AdminAction
            Just (weekdayIndex, name, isActive) -> do
                _ <- dayName
                    |> set #weekdayIndex weekdayIndex
                    |> set #name name
                    |> set #isActive isActive
                    |> updateRecord
                setSuccessMessage "Day name updated"
                redirectTo AdminAction

fetchCurrentVenuePayLevels :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO [PayLevel]
fetchCurrentVenuePayLevels =
    query @PayLevel
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> orderByAsc #createdAt
        |> fetch

fetchCurrentVenueShiftTypes :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO [ShiftType]
fetchCurrentVenueShiftTypes =
    query @ShiftType
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> orderByAsc #createdAt
        |> fetch

fetchCurrentVenueSlotNames :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO [SlotName]
fetchCurrentVenueSlotNames =
    query @SlotName
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> orderByAsc #createdAt
        |> fetch

fetchCurrentVenueDayNames :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO [DayName]
fetchCurrentVenueDayNames =
    query @DayName
        |> filterWhere (#venueId, unpackId currentVenueId)
        |> orderByAsc #weekdayIndex
        |> fetch

parseRequiredName :: (?context :: ControllerContext) => ByteString -> Text -> IO (Maybe Text)
parseRequiredName paramName errorMessage =
    let value = Text.strip (paramOrDefault "" paramName)
     in if Text.null value
            then do
                setErrorMessage errorMessage
                pure Nothing
            else pure (Just value)

parseIsActiveParam :: (?context :: ControllerContext) => Bool
parseIsActiveParam = paramOrDefault "true" "isActive" == ("true" :: Text)

parseDefaultPayLevelId :: (?context :: ControllerContext, ?modelContext :: ModelContext) => IO (Maybe (Id PayLevel))
parseDefaultPayLevelId =
    case paramOrNothing @(Id PayLevel) "defaultPayLevelId" of
        Nothing -> do
            setErrorMessage "Choose a default pay level."
            pure Nothing
        Just payLevelId -> do
            maybePayLevel <-
                query @PayLevel
                    |> filterWhere (#venueId, unpackId currentVenueId)
                    |> filterWhere (#id, payLevelId)
                    |> fetchOneOrNothing
            case maybePayLevel of
                Nothing -> do
                    setErrorMessage "Choose a default pay level from the current venue."
                    pure Nothing
                Just _ ->
                    pure (Just payLevelId)

parseDayNameParams ::
    (?context :: ControllerContext, ?modelContext :: ModelContext) =>
    Maybe DayName ->
    IO (Maybe (Int, Text, Bool))
parseDayNameParams existingDayName = do
    let maybeWeekdayIndex = paramOrNothing @Int "weekdayIndex"
    case maybeWeekdayIndex of
        Nothing -> do
            setErrorMessage "Choose a weekday."
            pure Nothing
        Just weekdayIndex
            | weekdayIndex < 0 || weekdayIndex > 6 -> do
                setErrorMessage "Weekday must be between 0 and 6."
                pure Nothing
            | otherwise ->
                maybeName <- parseRequiredName "name" "Day name is required."
                case maybeName of
                    Nothing -> pure Nothing
                    Just name -> do
                        dayNames <- fetchCurrentVenueDayNames
                        let conflicts =
                                any
                                    (\dayName ->
                                        dayName.weekdayIndex == weekdayIndex
                                            && maybe True (\existing -> get #id existing /= get #id dayName) existingDayName
                                    )
                                    dayNames
                        if conflicts
                            then do
                                setErrorMessage "That weekday already has a configured day name for this venue."
                                pure Nothing
                            else pure (Just (weekdayIndex, name, parseIsActiveParam))
