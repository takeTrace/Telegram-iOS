import Foundation

private let fallbackDict: [String: String] = {
    guard let mainPath = Bundle.main.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: mainPath) else {
        return [:]
    }
    guard let path = bundle.path(forResource: "Localizable", ofType: "strings") else {
        return [:]
    }
    guard let dict = NSDictionary(contentsOf: URL(fileURLWithPath: path)) as? [String: String] else {
        return [:]
    }
    return dict
}()

private extension PluralizationForm {
    var canonicalSuffix: String {
        switch self {
            case .zero:
                return "_0"
            case .one:
                return "_1"
            case .two:
                return "_2"
            case .few:
                return "_3_10"
            case .many:
                return "_many"
            case .other:
                return "_any"
        }
    }
}

public final class PresentationStringsComponent {
    public let languageCode: String
    public let localizedName: String
    public let pluralizationRulesCode: String?
    public let dict: [String: String]
    
    public init(languageCode: String, localizedName: String, pluralizationRulesCode: String?, dict: [String: String]) {
        self.languageCode = languageCode
        self.localizedName = localizedName
        self.pluralizationRulesCode = pluralizationRulesCode
        self.dict = dict
    }
}
        
private func getValue(_ primaryComponent: PresentationStringsComponent, _ secondaryComponent: PresentationStringsComponent?, _ key: String) -> String {
    if let value = primaryComponent.dict[key] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[key] {
        return value
    } else if let value = fallbackDict[key] {
        return value
    } else {
        return key
    }
}

private func getValueWithForm(_ primaryComponent: PresentationStringsComponent, _ secondaryComponent: PresentationStringsComponent?, _ key: String, _ form: PluralizationForm) -> String {
    let builtKey = key + form.canonicalSuffix
    if let value = primaryComponent.dict[builtKey] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[builtKey] {
        return value
    } else if let value = fallbackDict[builtKey] {
        return value
    }
    return key
}
        
private let argumentRegex = try! NSRegularExpression(pattern: "%(((\\d+)\\$)?)([@df])", options: [])
private func extractArgumentRanges(_ value: String) -> [(Int, NSRange)] {
    var result: [(Int, NSRange)] = []
    let string = value as NSString
    let matches = argumentRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    var index = 0
    for match in matches {
        var currentIndex = index
        if match.range(at: 3).location != NSNotFound {
            currentIndex = Int(string.substring(with: match.range(at: 3)))! - 1
        }
        result.append((currentIndex, match.range(at: 0)))
        index += 1
    }
    result.sort(by: { $0.1.location < $1.1.location })
    return result
}
    
func formatWithArgumentRanges(_ value: String, _ ranges: [(Int, NSRange)], _ arguments: [String]) -> (String, [(Int, NSRange)]) {
    let string = value as NSString
    
    var resultingRanges: [(Int, NSRange)] = []

    var currentLocation = 0

    let result = NSMutableString()
    for (index, range) in ranges {
        if currentLocation < range.location {
            result.append(string.substring(with: NSRange(location: currentLocation, length: range.location - currentLocation)))
        }
        resultingRanges.append((index, NSRange(location: result.length, length: (arguments[index] as NSString).length)))
        result.append(arguments[index])
        currentLocation = range.location + range.length
    }
    if currentLocation != string.length {
        result.append(string.substring(with: NSRange(location: currentLocation, length: string.length - currentLocation)))
    }
    return (result as String, resultingRanges)
}
        
private final class DataReader {
    private let data: Data
    private var ptr: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    func readInt32() -> Int32 {
        assert(self.ptr + 4 <= self.data.count)
        let result = self.data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Int32 in
            var value: Int32 = 0
            memcpy(&value, bytes.advanced(by: self.ptr), 4)
            return value
        }
        self.ptr += 4
        return result
    }

    func readString() -> String {
        let length = Int(self.readInt32())
        assert(self.ptr + length <= self.data.count)
        let value = String(data: self.data.subdata(in: self.ptr ..< self.ptr + length), encoding: .utf8)!
        self.ptr += length
        return value
    }
}
        
private func loadMapping() -> ([Int], [String], [Int], [Int], [String]) {
    guard let filePath = frameworkBundle.path(forResource: "PresentationStrings", ofType: "mapping") else {
        fatalError()
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        fatalError()
    }

    let reader = DataReader(data)

    let idCount = Int(reader.readInt32())
    var sIdList: [Int] = []
    var sKeyList: [String] = []
    var sArgIdList: [Int] = []
    for _ in 0 ..< idCount {
        let id = Int(reader.readInt32())
        sIdList.append(id)
        sKeyList.append(reader.readString())
        if reader.readInt32() != 0 {
            sArgIdList.append(id)
        }
    }

    let pCount = Int(reader.readInt32())
    var pIdList: [Int] = []
    var pKeyList: [String] = []
    for _ in 0 ..< Int(pCount) {
        pIdList.append(Int(reader.readInt32()))
        pKeyList.append(reader.readString())
    }

    return (sIdList, sKeyList, sArgIdList, pIdList, pKeyList)
}

private let keyMapping: ([Int], [String], [Int], [Int], [String]) = loadMapping()
        
public final class PresentationStrings {
    public let lc: UInt32
    
    public let primaryComponent: PresentationStringsComponent
    public let secondaryComponent: PresentationStringsComponent?
    public let baseLanguageCode: String
    public let groupingSeparator: String
        
    private let _s: [Int: String]
    private let _r: [Int: [(Int, NSRange)]]
    private let _ps: [Int: String]
    public var CallFeedback_ReasonSilentLocal: String { return self._s[0]! }
    public var StickerPack_ShowStickers: String { return self._s[1]! }
    public var Map_PullUpForPlaces: String { return self._s[2]! }
    public var Channel_Status: String { return self._s[4]! }
    public var TwoStepAuth_ChangePassword: String { return self._s[5]! }
    public var Map_LiveLocationFor1Hour: String { return self._s[6]! }
    public var CheckoutInfo_ShippingInfoAddress2Placeholder: String { return self._s[7]! }
    public var Settings_AppleWatch: String { return self._s[8]! }
    public var Login_InvalidCountryCode: String { return self._s[9]! }
    public var WebSearch_RecentSectionTitle: String { return self._s[10]! }
    public var UserInfo_DeleteContact: String { return self._s[11]! }
    public var ShareFileTip_CloseTip: String { return self._s[12]! }
    public var UserInfo_Invite: String { return self._s[13]! }
    public var Passport_Identity_MiddleName: String { return self._s[14]! }
    public var Passport_Identity_FrontSideHelp: String { return self._s[15]! }
    public var Month_GenDecember: String { return self._s[17]! }
    public var Common_Yes: String { return self._s[18]! }
    public func EncryptionKey_Description(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[19]!, self._r[19]!, [_1, _2])
    }
    public var Channel_AdminLogFilter_EventsLeaving: String { return self._s[20]! }
    public var WallpaperPreview_PreviewBottomText: String { return self._s[21]! }
    public func Notification_PinnedStickerMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[22]!, self._r[22]!, [_0])
    }
    public var Passport_Address_ScansHelp: String { return self._s[23]! }
    public var FastTwoStepSetup_PasswordHelp: String { return self._s[24]! }
    public var SettingsSearch_Synonyms_Notifications_Title: String { return self._s[25]! }
    public var AutoDownloadSettings_Files: String { return self._s[26]! }
    public var LastSeen_Lately: String { return self._s[31]! }
    public func PUSH_CHANNEL_MESSAGE_VIDEOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[32]!, self._r[32]!, [_1, _2])
    }
    public var Camera_Discard: String { return self._s[33]! }
    public var Channel_EditAdmin_PermissinAddAdminOff: String { return self._s[34]! }
    public var Login_InvalidPhoneError: String { return self._s[36]! }
    public var SettingsSearch_Synonyms_Privacy_AuthSessions: String { return self._s[37]! }
    public var Conversation_Moderate_Delete: String { return self._s[38]! }
    public var Conversation_DeleteMessagesForEveryone: String { return self._s[39]! }
    public var WatchRemote_AlertOpen: String { return self._s[40]! }
    public func MediaPicker_Nof(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[41]!, self._r[41]!, [_0])
    }
    public var AutoDownloadSettings_MediaTypes: String { return self._s[43]! }
    public var Watch_GroupInfo_Title: String { return self._s[44]! }
    public var Passport_Identity_AddPersonalDetails: String { return self._s[45]! }
    public var Channel_Info_Members: String { return self._s[46]! }
    public var LoginPassword_InvalidPasswordError: String { return self._s[48]! }
    public var Conversation_LiveLocation: String { return self._s[49]! }
    public var PrivacyLastSeenSettings_CustomShareSettingsHelp: String { return self._s[50]! }
    public var NetworkUsageSettings_BytesReceived: String { return self._s[52]! }
    public var Stickers_Search: String { return self._s[54]! }
    public var NotificationsSound_Synth: String { return self._s[55]! }
    public var LogoutOptions_LogOutInfo: String { return self._s[56]! }
    public var NetworkUsageSettings_MediaAudioDataSection: String { return self._s[58]! }
    public var AutoNightTheme_UseSunsetSunrise: String { return self._s[60]! }
    public var FastTwoStepSetup_Title: String { return self._s[61]! }
    public var Channel_Info_BlackList: String { return self._s[62]! }
    public var Channel_AdminLog_InfoPanelTitle: String { return self._s[63]! }
    public var Conversation_OpenFile: String { return self._s[64]! }
    public var SecretTimer_ImageDescription: String { return self._s[65]! }
    public var StickerSettings_ContextInfo: String { return self._s[66]! }
    public var TwoStepAuth_GenericHelp: String { return self._s[68]! }
    public var AutoDownloadSettings_Unlimited: String { return self._s[69]! }
    public var PrivacyLastSeenSettings_NeverShareWith_Title: String { return self._s[70]! }
    public var AutoDownloadSettings_DataUsageHigh: String { return self._s[71]! }
    public func PUSH_CHAT_MESSAGE_VIDEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[72]!, self._r[72]!, [_1, _2])
    }
    public var Notifications_AddExceptionTitle: String { return self._s[73]! }
    public var Watch_MessageView_Reply: String { return self._s[74]! }
    public var Tour_Text6: String { return self._s[75]! }
    public var TwoStepAuth_SetupPasswordEnterPasswordChange: String { return self._s[76]! }
    public func Notification_PinnedAnimationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[77]!, self._r[77]!, [_0])
    }
    public func ShareFileTip_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[78]!, self._r[78]!, [_0])
    }
    public var AccessDenied_LocationDenied: String { return self._s[79]! }
    public var CallSettings_RecentCalls: String { return self._s[80]! }
    public var ConversationProfile_LeaveDeleteAndExit: String { return self._s[81]! }
    public var Channel_Members_AddAdminErrorBlacklisted: String { return self._s[82]! }
    public var Passport_Authorize: String { return self._s[83]! }
    public var StickerPacksSettings_ArchivedMasks_Info: String { return self._s[84]! }
    public var AutoDownloadSettings_Videos: String { return self._s[85]! }
    public var TwoStepAuth_ReEnterPasswordTitle: String { return self._s[86]! }
    public var Tour_StartButton: String { return self._s[87]! }
    public var Watch_AppName: String { return self._s[89]! }
    public var StickerPack_ErrorNotFound: String { return self._s[90]! }
    public var Channel_Info_Subscribers: String { return self._s[91]! }
    public func Channel_AdminLog_MessageGroupPreHistoryVisible(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[92]!, self._r[92]!, [_0])
    }
    public func DialogList_PinLimitError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[93]!, self._r[93]!, [_0])
    }
    public var Conversation_StopLiveLocation: String { return self._s[95]! }
    public var Channel_AdminLogFilter_EventsAll: String { return self._s[96]! }
    public var GroupInfo_InviteLink_CopyAlert_Success: String { return self._s[98]! }
    public var Username_LinkCopied: String { return self._s[100]! }
    public var GroupRemoved_Title: String { return self._s[101]! }
    public var SecretVideo_Title: String { return self._s[102]! }
    public func PUSH_PINNED_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[103]!, self._r[103]!, [_1])
    }
    public var AccessDenied_PhotosAndVideos: String { return self._s[104]! }
    public func PUSH_CHANNEL_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[105]!, self._r[105]!, [_1])
    }
    public var Map_OpenInGoogleMaps: String { return self._s[106]! }
    public func Time_PreciseDate_m12(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[107]!, self._r[107]!, [_1, _2, _3])
    }
    public func Channel_AdminLog_MessageKickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[108]!, self._r[108]!, [_1, _2])
    }
    public var Call_StatusRinging: String { return self._s[109]! }
    public var SettingsSearch_Synonyms_EditProfile_Username: String { return self._s[110]! }
    public var Group_Username_InvalidStartsWithNumber: String { return self._s[111]! }
    public var UserInfo_NotificationsEnabled: String { return self._s[112]! }
    public var Map_Search: String { return self._s[113]! }
    public var Login_TermsOfServiceHeader: String { return self._s[115]! }
    public func Notification_PinnedVideoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[116]!, self._r[116]!, [_0])
    }
    public func Channel_AdminLog_MessageToggleSignaturesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[117]!, self._r[117]!, [_0])
    }
    public var TwoStepAuth_SetupPasswordConfirmPassword: String { return self._s[118]! }
    public var Weekday_Today: String { return self._s[119]! }
    public func InstantPage_AuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[121]!, self._r[121]!, [_1, _2])
    }
    public func Conversation_MessageDialogRetryAll(_ _1: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[122]!, self._r[122]!, ["\(_1)"])
    }
    public var Notification_PassportValuePersonalDetails: String { return self._s[124]! }
    public var Channel_AdminLog_MessagePreviousLink: String { return self._s[125]! }
    public var ChangePhoneNumberNumber_NewNumber: String { return self._s[126]! }
    public var ApplyLanguage_LanguageNotSupportedError: String { return self._s[127]! }
    public var TwoStepAuth_ChangePasswordDescription: String { return self._s[128]! }
    public var PhotoEditor_BlurToolLinear: String { return self._s[129]! }
    public var Contacts_PermissionsAllowInSettings: String { return self._s[130]! }
    public var Weekday_ShortMonday: String { return self._s[131]! }
    public var Cache_KeepMedia: String { return self._s[132]! }
    public var Passport_FieldIdentitySelfieHelp: String { return self._s[133]! }
    public func PUSH_PINNED_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[134]!, self._r[134]!, [_1, _2])
    }
    public var Conversation_ClousStorageInfo_Description4: String { return self._s[135]! }
    public var Passport_Language_ru: String { return self._s[136]! }
    public func Notification_CreatedChatWithTitle(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[137]!, self._r[137]!, [_0, _1])
    }
    public var WallpaperPreview_PatternIntensity: String { return self._s[138]! }
    public var TwoStepAuth_RecoveryUnavailable: String { return self._s[139]! }
    public var EnterPasscode_TouchId: String { return self._s[140]! }
    public var PhotoEditor_QualityVeryHigh: String { return self._s[143]! }
    public var Checkout_NewCard_SaveInfo: String { return self._s[145]! }
    public var Gif_NoGifsPlaceholder: String { return self._s[147]! }
    public var ChatSettings_AutoDownloadEnabled: String { return self._s[149]! }
    public var NetworkUsageSettings_BytesSent: String { return self._s[150]! }
    public var Checkout_PasswordEntry_Pay: String { return self._s[151]! }
    public var AuthSessions_TerminateSession: String { return self._s[152]! }
    public var Message_File: String { return self._s[153]! }
    public var MediaPicker_VideoMuteDescription: String { return self._s[154]! }
    public var SocksProxySetup_ProxyStatusConnected: String { return self._s[155]! }
    public var TwoStepAuth_RecoveryCode: String { return self._s[156]! }
    public var EnterPasscode_EnterCurrentPasscode: String { return self._s[157]! }
    public func TwoStepAuth_EnterPasswordHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[158]!, self._r[158]!, [_0])
    }
    public var Conversation_Moderate_Report: String { return self._s[160]! }
    public var TwoStepAuth_EmailInvalid: String { return self._s[161]! }
    public var Passport_Language_ms: String { return self._s[162]! }
    public var Channel_Edit_AboutItem: String { return self._s[164]! }
    public var DialogList_SearchSectionGlobal: String { return self._s[168]! }
    public var AttachmentMenu_WebSearch: String { return self._s[169]! }
    public var PasscodeSettings_TurnPasscodeOn: String { return self._s[170]! }
    public var Channel_BanUser_Title: String { return self._s[171]! }
    public var WallpaperPreview_SwipeTopText: String { return self._s[172]! }
    public var ChatSearch_SearchPlaceholder: String { return self._s[174]! }
    public var Passport_FieldAddressTranslationHelp: String { return self._s[175]! }
    public var NotificationsSound_Aurora: String { return self._s[176]! }
    public func FileSize_GB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[177]!, self._r[177]!, [_0])
    }
    public var AuthSessions_LoggedInWithTelegram: String { return self._s[180]! }
    public func Privacy_GroupsAndChannels_InviteToGroupError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[181]!, self._r[181]!, [_0, _1])
    }
    public var Passport_PasswordNext: String { return self._s[182]! }
    public var Bot_GroupStatusReadsHistory: String { return self._s[183]! }
    public var EmptyGroupInfo_Line2: String { return self._s[184]! }
    public var Settings_FAQ_Intro: String { return self._s[186]! }
    public var PrivacySettings_PasscodeAndTouchId: String { return self._s[188]! }
    public var FeaturedStickerPacks_Title: String { return self._s[189]! }
    public var TwoStepAuth_PasswordRemoveConfirmation: String { return self._s[190]! }
    public var Username_Title: String { return self._s[191]! }
    public func Message_StickerText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[192]!, self._r[192]!, [_0])
    }
    public var Localization_LanguageOther: String { return self._s[193]! }
    public var Stickers_SuggestStickers: String { return self._s[194]! }
    public func Channel_AdminLog_MessageRemovedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[195]!, self._r[195]!, [_0])
    }
    public var NotificationSettings_ShowNotificationsFromAccountsSection: String { return self._s[196]! }
    public var Channel_AdminLogFilter_EventsAdmins: String { return self._s[197]! }
    public var Conversation_DefaultRestrictedStickers: String { return self._s[198]! }
    public func Notification_PinnedDeletedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[199]!, self._r[199]!, [_0])
    }
    public var Group_UpgradeConfirmation: String { return self._s[201]! }
    public var DialogList_Unpin: String { return self._s[202]! }
    public var Passport_Identity_DateOfBirth: String { return self._s[203]! }
    public var Month_ShortOctober: String { return self._s[204]! }
    public var SettingsSearch_Synonyms_Privacy_Data_ContactsSync: String { return self._s[205]! }
    public var Notification_CallCanceledShort: String { return self._s[206]! }
    public var Passport_Phone_Help: String { return self._s[207]! }
    public var Passport_Language_az: String { return self._s[209]! }
    public var CreatePoll_TextPlaceholder: String { return self._s[211]! }
    public var Passport_Identity_DocumentNumber: String { return self._s[212]! }
    public var PhotoEditor_CurvesRed: String { return self._s[213]! }
    public var PhoneNumberHelp_Alert: String { return self._s[215]! }
    public var SocksProxySetup_Port: String { return self._s[216]! }
    public var Checkout_PayNone: String { return self._s[217]! }
    public var AutoDownloadSettings_WiFi: String { return self._s[218]! }
    public var GroupInfo_GroupType: String { return self._s[219]! }
    public var StickerSettings_ContextHide: String { return self._s[220]! }
    public var Passport_Address_OneOfTypeTemporaryRegistration: String { return self._s[221]! }
    public var Group_Setup_HistoryTitle: String { return self._s[223]! }
    public var Passport_Identity_FilesUploadNew: String { return self._s[224]! }
    public var PasscodeSettings_AutoLock: String { return self._s[225]! }
    public var Passport_Title: String { return self._s[226]! }
    public var Channel_AdminLogFilter_EventsNewSubscribers: String { return self._s[227]! }
    public var GroupPermission_NoSendGifs: String { return self._s[228]! }
    public var State_WaitingForNetwork: String { return self._s[230]! }
    public func Notification_Invited(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[231]!, self._r[231]!, [_0, _1])
    }
    public var Calls_NotNow: String { return self._s[233]! }
    public var UserInfo_SendMessage: String { return self._s[234]! }
    public var TwoStepAuth_PasswordSet: String { return self._s[235]! }
    public var Passport_DeleteDocument: String { return self._s[236]! }
    public var SocksProxySetup_AddProxyTitle: String { return self._s[237]! }
    public func PUSH_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[238]!, self._r[238]!, [_1])
    }
    public var GroupRemoved_Remove: String { return self._s[239]! }
    public var Passport_FieldIdentity: String { return self._s[240]! }
    public var Group_Setup_TypePrivateHelp: String { return self._s[241]! }
    public var Conversation_Processing: String { return self._s[243]! }
    public var ChatSettings_AutoPlayAnimations: String { return self._s[245]! }
    public var AuthSessions_LogOutApplicationsHelp: String { return self._s[248]! }
    public var Month_GenFebruary: String { return self._s[249]! }
    public func Login_InvalidPhoneEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[251]!, self._r[251]!, [_1, _2, _3, _4, _5])
    }
    public var Passport_Identity_TypeIdentityCard: String { return self._s[252]! }
    public var AutoDownloadSettings_DataUsageMedium: String { return self._s[254]! }
    public var GroupInfo_AddParticipant: String { return self._s[255]! }
    public var KeyCommand_SendMessage: String { return self._s[256]! }
    public var Map_LiveLocationShowAll: String { return self._s[258]! }
    public var WallpaperSearch_ColorOrange: String { return self._s[260]! }
    public var Checkout_Receipt_Title: String { return self._s[261]! }
    public var WallpaperPreview_PreviewTopText: String { return self._s[262]! }
    public var Message_Contact: String { return self._s[263]! }
    public var Call_StatusIncoming: String { return self._s[264]! }
    public func Channel_AdminLog_MessageKickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[265]!, self._r[265]!, [_1])
    }
    public func PUSH_ENCRYPTED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[267]!, self._r[267]!, [_1])
    }
    public var Passport_FieldIdentityDetailsHelp: String { return self._s[268]! }
    public var Conversation_ViewChannel: String { return self._s[269]! }
    public func Time_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[270]!, self._r[270]!, [_0])
    }
    public var Passport_Language_nl: String { return self._s[272]! }
    public var Camera_Retake: String { return self._s[273]! }
    public var AuthSessions_LogOutApplications: String { return self._s[274]! }
    public var ApplyLanguage_ApplySuccess: String { return self._s[275]! }
    public var Tour_Title6: String { return self._s[276]! }
    public var Map_ChooseAPlace: String { return self._s[277]! }
    public var CallSettings_Never: String { return self._s[279]! }
    public func Notification_ChangedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[280]!, self._r[280]!, [_0])
    }
    public var ChannelRemoved_RemoveInfo: String { return self._s[281]! }
    public func AutoDownloadSettings_PreloadVideoInfo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[282]!, self._r[282]!, [_0])
    }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsExceptions: String { return self._s[283]! }
    public var GroupInfo_InviteLink_Title: String { return self._s[284]! }
    public func Channel_AdminLog_MessageUnkickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[285]!, self._r[285]!, [_1, _2])
    }
    public var KeyCommand_ScrollUp: String { return self._s[286]! }
    public var ContactInfo_URLLabelHomepage: String { return self._s[287]! }
    public func Conversation_EncryptedPlaceholderTitleOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[288]!, self._r[288]!, [_0])
    }
    public var CallFeedback_ReasonDistortedSpeech: String { return self._s[289]! }
    public var Watch_LastSeen_WithinAWeek: String { return self._s[290]! }
    public var Weekday_Tuesday: String { return self._s[292]! }
    public var UserInfo_StartSecretChat: String { return self._s[294]! }
    public var Passport_Identity_FilesTitle: String { return self._s[295]! }
    public var Permissions_NotificationsAllow_v0: String { return self._s[296]! }
    public var DialogList_DeleteConversationConfirmation: String { return self._s[298]! }
    public var AuthSessions_Sessions: String { return self._s[299]! }
    public func Settings_KeepPhoneNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[301]!, self._r[301]!, [_0])
    }
    public var TwoStepAuth_RecoveryEmailChangeDescription: String { return self._s[302]! }
    public var Call_StatusWaiting: String { return self._s[303]! }
    public var CreateGroup_SoftUserLimitAlert: String { return self._s[304]! }
    public var FastTwoStepSetup_HintHelp: String { return self._s[305]! }
    public var WallpaperPreview_CustomColorBottomText: String { return self._s[306]! }
    public var LogoutOptions_AddAccountText: String { return self._s[307]! }
    public var Settings_LogoutConfirmationText: String { return self._s[308]! }
    public var Passport_Identity_TypePassport: String { return self._s[310]! }
    public func PUSH_MESSAGE_VIDEOS(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[313]!, self._r[313]!, [_1, _2])
    }
    public var SocksProxySetup_SaveProxy: String { return self._s[314]! }
    public var AccessDenied_SaveMedia: String { return self._s[315]! }
    public var Checkout_ErrorInvoiceAlreadyPaid: String { return self._s[317]! }
    public var Settings_Title: String { return self._s[319]! }
    public var Contacts_InviteSearchLabel: String { return self._s[321]! }
    public var ConvertToSupergroup_Title: String { return self._s[322]! }
    public func Channel_AdminLog_CaptionEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[323]!, self._r[323]!, [_0])
    }
    public var InfoPlist_NSSiriUsageDescription: String { return self._s[324]! }
    public func PUSH_MESSAGE_CHANNEL_MESSAGE_GAME_SCORE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[325]!, self._r[325]!, [_1, _2, _3])
    }
    public var ChatSettings_AutomaticPhotoDownload: String { return self._s[326]! }
    public var UserInfo_BotHelp: String { return self._s[327]! }
    public var PrivacySettings_LastSeenEverybody: String { return self._s[328]! }
    public var Checkout_Name: String { return self._s[329]! }
    public var AutoDownloadSettings_DataUsage: String { return self._s[330]! }
    public var Channel_BanUser_BlockFor: String { return self._s[331]! }
    public var Checkout_ShippingAddress: String { return self._s[332]! }
    public var AutoDownloadSettings_MaxVideoSize: String { return self._s[333]! }
    public var Privacy_PaymentsClearInfoDoneHelp: String { return self._s[334]! }
    public var Privacy_Forwards: String { return self._s[335]! }
    public var Channel_BanUser_PermissionSendPolls: String { return self._s[336]! }
    public func SecretVideo_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[339]!, self._r[339]!, [_0])
    }
    public var Contacts_SortedByName: String { return self._s[340]! }
    public var Group_LeaveGroup: String { return self._s[341]! }
    public var Settings_UsernameEmpty: String { return self._s[342]! }
    public func Notification_PinnedPollMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[343]!, self._r[343]!, [_0])
    }
    public func TwoStepAuth_ConfirmEmailDescription(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[344]!, self._r[344]!, [_1])
    }
    public var Message_ImageExpired: String { return self._s[345]! }
    public var TwoStepAuth_RecoveryFailed: String { return self._s[347]! }
    public var UserInfo_AddToExisting: String { return self._s[348]! }
    public var TwoStepAuth_EnabledSuccess: String { return self._s[349]! }
    public var SettingsSearch_Synonyms_Appearance_ChatBackground_SetColor: String { return self._s[350]! }
    public func PUSH_CHANNEL_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[351]!, self._r[351]!, [_1])
    }
    public var Notifications_GroupNotificationsAlert: String { return self._s[352]! }
    public var Passport_Language_km: String { return self._s[353]! }
    public var SocksProxySetup_AdNoticeHelp: String { return self._s[355]! }
    public var Notification_CallMissedShort: String { return self._s[356]! }
    public var ReportPeer_ReasonOther_Send: String { return self._s[357]! }
    public var Watch_Compose_Send: String { return self._s[358]! }
    public var Passport_Identity_TypeInternalPassportUploadScan: String { return self._s[361]! }
    public var Conversation_HoldForVideo: String { return self._s[362]! }
    public var CheckoutInfo_ErrorCityInvalid: String { return self._s[364]! }
    public var Appearance_AutoNightThemeDisabled: String { return self._s[366]! }
    public var Channel_LinkItem: String { return self._s[367]! }
    public func PrivacySettings_LastSeenContactsMinusPlus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[368]!, self._r[368]!, [_0, _1])
    }
    public func Passport_Identity_NativeNameTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[371]!, self._r[371]!, [_0])
    }
    public var Passport_Language_dv: String { return self._s[372]! }
    public var Undo_LeftChannel: String { return self._s[373]! }
    public var Notifications_ExceptionsMuted: String { return self._s[374]! }
    public var ChatList_UnhideAction: String { return self._s[375]! }
    public var Conversation_ContextMenuShare: String { return self._s[376]! }
    public var Conversation_ContextMenuStickerPackInfo: String { return self._s[377]! }
    public var ShareFileTip_Title: String { return self._s[378]! }
    public var NotificationsSound_Chord: String { return self._s[379]! }
    public func PUSH_CHAT_RETURNED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[380]!, self._r[380]!, [_1, _2])
    }
    public var Passport_Address_EditTemporaryRegistration: String { return self._s[381]! }
    public func Notification_Joined(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[382]!, self._r[382]!, [_0])
    }
    public var Notification_CallOutgoingShort: String { return self._s[384]! }
    public func Watch_Time_ShortFullAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[385]!, self._r[385]!, [_1, _2])
    }
    public var Passport_Address_TypeUtilityBill: String { return self._s[386]! }
    public var Privacy_Forwards_LinkIfAllowed: String { return self._s[387]! }
    public var ReportPeer_Report: String { return self._s[388]! }
    public var SettingsSearch_Synonyms_Proxy_Title: String { return self._s[389]! }
    public var GroupInfo_DeactivatedStatus: String { return self._s[390]! }
    public var StickerPack_Send: String { return self._s[391]! }
    public var Login_CodeSentInternal: String { return self._s[392]! }
    public var GroupInfo_InviteLink_LinkSection: String { return self._s[393]! }
    public func Channel_AdminLog_MessageDeleted(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[394]!, self._r[394]!, [_0])
    }
    public func Conversation_EncryptionWaiting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[396]!, self._r[396]!, [_0])
    }
    public var Channel_BanUser_PermissionSendStickersAndGifs: String { return self._s[397]! }
    public func PUSH_PINNED_GAME(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[398]!, self._r[398]!, [_1])
    }
    public var ReportPeer_ReasonViolence: String { return self._s[400]! }
    public var Map_Locating: String { return self._s[401]! }
    public var AutoDownloadSettings_GroupChats: String { return self._s[403]! }
    public var CheckoutInfo_SaveInfo: String { return self._s[404]! }
    public var SharedMedia_EmptyLinksText: String { return self._s[406]! }
    public var Passport_Address_CityPlaceholder: String { return self._s[407]! }
    public var CheckoutInfo_ErrorStateInvalid: String { return self._s[408]! }
    public var Privacy_ProfilePhoto_CustomHelp: String { return self._s[409]! }
    public var Channel_AdminLog_CanAddAdmins: String { return self._s[411]! }
    public func PUSH_CHANNEL_MESSAGE_FWD(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[412]!, self._r[412]!, [_1])
    }
    public func Time_MonthOfYear_m8(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[413]!, self._r[413]!, [_0])
    }
    public var InfoPlist_NSLocationWhenInUseUsageDescription: String { return self._s[414]! }
    public var GroupInfo_InviteLink_RevokeAlert_Success: String { return self._s[415]! }
    public var ChangePhoneNumberCode_Code: String { return self._s[416]! }
    public func UserInfo_NotificationsDefaultSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[417]!, self._r[417]!, [_0])
    }
    public var TwoStepAuth_SetupEmail: String { return self._s[418]! }
    public var HashtagSearch_AllChats: String { return self._s[419]! }
    public var SettingsSearch_Synonyms_Data_AutoDownloadUsingCellular: String { return self._s[421]! }
    public func ChatList_DeleteForEveryone(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[422]!, self._r[422]!, [_0])
    }
    public var PhotoEditor_QualityHigh: String { return self._s[424]! }
    public func Passport_Phone_UseTelegramNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[425]!, self._r[425]!, [_0])
    }
    public var ApplyLanguage_ApplyLanguageAction: String { return self._s[426]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsPreview: String { return self._s[427]! }
    public var Message_LiveLocation: String { return self._s[428]! }
    public var Cache_LowDiskSpaceText: String { return self._s[429]! }
    public var Conversation_SendMessage: String { return self._s[430]! }
    public var AuthSessions_EmptyTitle: String { return self._s[431]! }
    public var CallSettings_UseLessData: String { return self._s[432]! }
    public var NetworkUsageSettings_MediaDocumentDataSection: String { return self._s[433]! }
    public var Stickers_AddToFavorites: String { return self._s[434]! }
    public var PhotoEditor_QualityLow: String { return self._s[435]! }
    public var Watch_UserInfo_Unblock: String { return self._s[436]! }
    public var Settings_Logout: String { return self._s[437]! }
    public func PUSH_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[438]!, self._r[438]!, [_1])
    }
    public var ContactInfo_PhoneLabelWork: String { return self._s[439]! }
    public var ChannelInfo_Stats: String { return self._s[440]! }
    public func Date_ChatDateHeader(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[441]!, self._r[441]!, [_1, _2])
    }
    public func Message_ForwardedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[442]!, self._r[442]!, [_0])
    }
    public var Watch_Notification_Joined: String { return self._s[443]! }
    public var Group_Setup_TypePublicHelp: String { return self._s[444]! }
    public var Passport_Scans_UploadNew: String { return self._s[445]! }
    public var Checkout_LiabilityAlertTitle: String { return self._s[446]! }
    public var DialogList_Title: String { return self._s[449]! }
    public var NotificationSettings_ContactJoined: String { return self._s[450]! }
    public var GroupInfo_LabelAdmin: String { return self._s[451]! }
    public var KeyCommand_ChatInfo: String { return self._s[452]! }
    public var Conversation_EditingCaptionPanelTitle: String { return self._s[453]! }
    public var Call_ReportIncludeLog: String { return self._s[454]! }
    public func Notifications_ExceptionsChangeSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[457]!, self._r[457]!, [_0])
    }
    public var ChatAdmins_AllMembersAreAdmins: String { return self._s[458]! }
    public var Conversation_DefaultRestrictedInline: String { return self._s[459]! }
    public var Message_Sticker: String { return self._s[460]! }
    public var LastSeen_JustNow: String { return self._s[462]! }
    public var Passport_Email_EmailPlaceholder: String { return self._s[464]! }
    public var SettingsSearch_Synonyms_AppLanguage: String { return self._s[465]! }
    public var Channel_AdminLogFilter_EventsEditedMessages: String { return self._s[466]! }
    public var Channel_EditAdmin_PermissionsHeader: String { return self._s[467]! }
    public var TwoStepAuth_Email: String { return self._s[468]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsSound: String { return self._s[469]! }
    public var PhotoEditor_BlurToolOff: String { return self._s[470]! }
    public var Message_PinnedStickerMessage: String { return self._s[471]! }
    public var ContactInfo_PhoneLabelPager: String { return self._s[472]! }
    public var SettingsSearch_Synonyms_Appearance_TextSize: String { return self._s[473]! }
    public var Passport_DiscardMessageTitle: String { return self._s[474]! }
    public var Privacy_PaymentsTitle: String { return self._s[475]! }
    public var Appearance_ColorTheme: String { return self._s[477]! }
    public var UserInfo_ShareContact: String { return self._s[478]! }
    public var Passport_Address_TypePassportRegistration: String { return self._s[479]! }
    public var Common_More: String { return self._s[480]! }
    public var Watch_Message_Call: String { return self._s[481]! }
    public var Profile_EncryptionKey: String { return self._s[484]! }
    public var Privacy_TopPeers: String { return self._s[485]! }
    public var Conversation_StopPollConfirmation: String { return self._s[486]! }
    public var Privacy_TopPeersWarning: String { return self._s[488]! }
    public var SettingsSearch_Synonyms_Data_DownloadInBackground: String { return self._s[489]! }
    public var SettingsSearch_Synonyms_Data_Storage_KeepMedia: String { return self._s[490]! }
    public var DialogList_SearchSectionMessages: String { return self._s[493]! }
    public var Notifications_ChannelNotifications: String { return self._s[494]! }
    public var CheckoutInfo_ShippingInfoAddress1Placeholder: String { return self._s[495]! }
    public var Passport_Language_sk: String { return self._s[496]! }
    public var Notification_MessageLifetime1h: String { return self._s[497]! }
    public var Wallpaper_ResetWallpapersInfo: String { return self._s[498]! }
    public var Call_ReportSkip: String { return self._s[500]! }
    public var Cache_ServiceFiles: String { return self._s[501]! }
    public var Group_ErrorAddTooMuchAdmins: String { return self._s[502]! }
    public var Map_Hybrid: String { return self._s[503]! }
    public var ChatSettings_AutoDownloadVideos: String { return self._s[506]! }
    public var Channel_BanUser_PermissionEmbedLinks: String { return self._s[507]! }
    public var InfoPlist_NSLocationAlwaysAndWhenInUseUsageDescription: String { return self._s[508]! }
    public var SocksProxySetup_ProxyTelegram: String { return self._s[511]! }
    public func PUSH_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[512]!, self._r[512]!, [_1])
    }
    public var Channel_Username_CreatePrivateLinkHelp: String { return self._s[514]! }
    public func PUSH_CHAT_TITLE_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[515]!, self._r[515]!, [_1, _2])
    }
    public var Conversation_LiveLocationYou: String { return self._s[516]! }
    public var SettingsSearch_Synonyms_Privacy_Calls: String { return self._s[517]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsPreview: String { return self._s[518]! }
    public var UserInfo_ShareBot: String { return self._s[521]! }
    public func PUSH_AUTH_REGION(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[522]!, self._r[522]!, [_1, _2])
    }
    public var PhotoEditor_ShadowsTint: String { return self._s[523]! }
    public var Message_Audio: String { return self._s[524]! }
    public var Passport_Language_lt: String { return self._s[525]! }
    public func Message_PinnedTextMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[526]!, self._r[526]!, [_0])
    }
    public var Permissions_SiriText_v0: String { return self._s[527]! }
    public var Conversation_FileICloudDrive: String { return self._s[528]! }
    public var Notifications_Badge_IncludeMutedChats: String { return self._s[529]! }
    public func Notification_NewAuthDetected(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[530]!, self._r[530]!, [_1, _2, _3, _4, _5, _6])
    }
    public var DialogList_ProxyConnectionIssuesTooltip: String { return self._s[531]! }
    public func Time_MonthOfYear_m5(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[532]!, self._r[532]!, [_0])
    }
    public var Channel_SignMessages: String { return self._s[533]! }
    public func PUSH_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[534]!, self._r[534]!, [_1])
    }
    public var Compose_ChannelTokenListPlaceholder: String { return self._s[535]! }
    public var Passport_ScanPassport: String { return self._s[536]! }
    public var Watch_Suggestion_Thanks: String { return self._s[537]! }
    public var BlockedUsers_AddNew: String { return self._s[538]! }
    public func PUSH_CHAT_MESSAGE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[539]!, self._r[539]!, [_1, _2])
    }
    public var Watch_Message_Invoice: String { return self._s[540]! }
    public var SettingsSearch_Synonyms_Privacy_LastSeen: String { return self._s[541]! }
    public var Month_GenJuly: String { return self._s[542]! }
    public var SocksProxySetup_ProxySocks5: String { return self._s[543]! }
    public var Notification_ChannelInviterSelf: String { return self._s[545]! }
    public var CheckoutInfo_ReceiverInfoEmail: String { return self._s[546]! }
    public func ApplyLanguage_ChangeLanguageUnofficialText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[547]!, self._r[547]!, [_1, _2])
    }
    public var CheckoutInfo_Title: String { return self._s[548]! }
    public var Watch_Stickers_RecentPlaceholder: String { return self._s[549]! }
    public func Map_DistanceAway(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[550]!, self._r[550]!, [_0])
    }
    public var Passport_Identity_MainPage: String { return self._s[551]! }
    public var TwoStepAuth_ConfirmEmailResendCode: String { return self._s[552]! }
    public var Passport_Language_de: String { return self._s[553]! }
    public var Update_Title: String { return self._s[554]! }
    public var ContactInfo_PhoneLabelWorkFax: String { return self._s[555]! }
    public var Channel_AdminLog_BanEmbedLinks: String { return self._s[556]! }
    public var Passport_Email_UseTelegramEmailHelp: String { return self._s[557]! }
    public var Notifications_ChannelNotificationsPreview: String { return self._s[558]! }
    public var NotificationsSound_Telegraph: String { return self._s[559]! }
    public var Watch_LastSeen_ALongTimeAgo: String { return self._s[560]! }
    public var ChannelMembers_WhoCanAddMembers: String { return self._s[561]! }
    public func AutoDownloadSettings_UpTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[562]!, self._r[562]!, [_0])
    }
    public var Stickers_SuggestAll: String { return self._s[563]! }
    public var Conversation_ForwardTitle: String { return self._s[564]! }
    public func Notification_JoinedChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[565]!, self._r[565]!, [_0])
    }
    public var Calls_NewCall: String { return self._s[566]! }
    public var Call_StatusEnded: String { return self._s[567]! }
    public var AutoDownloadSettings_DataUsageLow: String { return self._s[568]! }
    public var Settings_ProxyConnected: String { return self._s[569]! }
    public var Channel_AdminLogFilter_EventsPinned: String { return self._s[570]! }
    public var PhotoEditor_QualityVeryLow: String { return self._s[571]! }
    public var Channel_AdminLogFilter_EventsDeletedMessages: String { return self._s[572]! }
    public var Passport_PasswordPlaceholder: String { return self._s[573]! }
    public var Message_PinnedInvoice: String { return self._s[574]! }
    public var Passport_Identity_IssueDate: String { return self._s[575]! }
    public var Passport_Language_pl: String { return self._s[576]! }
    public func ChannelInfo_ChannelForbidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[577]!, self._r[577]!, [_0])
    }
    public var SocksProxySetup_PasteFromClipboard: String { return self._s[578]! }
    public var Call_StatusConnecting: String { return self._s[579]! }
    public func Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[580]!, self._r[580]!, [_0])
    }
    public var ChatSettings_ConnectionType_UseProxy: String { return self._s[582]! }
    public var Common_Edit: String { return self._s[583]! }
    public var PrivacySettings_LastSeenNobody: String { return self._s[584]! }
    public func Notification_LeftChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[585]!, self._r[585]!, [_0])
    }
    public var GroupInfo_ChatAdmins: String { return self._s[586]! }
    public var PrivateDataSettings_Title: String { return self._s[587]! }
    public var Login_CancelPhoneVerificationStop: String { return self._s[588]! }
    public var ChatList_Read: String { return self._s[589]! }
    public var Undo_ChatClearedForBothSides: String { return self._s[590]! }
    public var GroupPermission_SectionTitle: String { return self._s[591]! }
    public func PUSH_CHAT_LEFT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[593]!, self._r[593]!, [_1, _2])
    }
    public var Checkout_ErrorPaymentFailed: String { return self._s[594]! }
    public var Update_UpdateApp: String { return self._s[595]! }
    public var Group_Username_RevokeExistingUsernamesInfo: String { return self._s[596]! }
    public var Settings_Appearance: String { return self._s[597]! }
    public var SettingsSearch_Synonyms_Stickers_SuggestStickers: String { return self._s[599]! }
    public var Watch_Location_Access: String { return self._s[600]! }
    public var ShareMenu_CopyShareLink: String { return self._s[602]! }
    public var TwoStepAuth_SetupHintTitle: String { return self._s[603]! }
    public func DialogList_SingleRecordingVideoMessageSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[605]!, self._r[605]!, [_0])
    }
    public var Notifications_ClassicTones: String { return self._s[606]! }
    public var Weekday_ShortWednesday: String { return self._s[607]! }
    public var WallpaperPreview_SwipeColorsBottomText: String { return self._s[608]! }
    public var Undo_LeftGroup: String { return self._s[611]! }
    public var Conversation_LinkDialogCopy: String { return self._s[612]! }
    public var KeyCommand_FocusOnInputField: String { return self._s[614]! }
    public var Contacts_SelectAll: String { return self._s[615]! }
    public var Preview_SaveToCameraRoll: String { return self._s[616]! }
    public var Wallpaper_Title: String { return self._s[617]! }
    public var Conversation_FilePhotoOrVideo: String { return self._s[618]! }
    public var AccessDenied_Camera: String { return self._s[619]! }
    public var Watch_Compose_CurrentLocation: String { return self._s[620]! }
    public func SecretImage_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[622]!, self._r[622]!, [_0])
    }
    public var GroupInfo_InvitationLinkDoesNotExist: String { return self._s[623]! }
    public var Passport_Language_ro: String { return self._s[624]! }
    public var CheckoutInfo_SaveInfoHelp: String { return self._s[625]! }
    public func Notification_SecretChatMessageScreenshot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[626]!, self._r[626]!, [_0])
    }
    public var Login_CancelPhoneVerification: String { return self._s[627]! }
    public var State_ConnectingToProxy: String { return self._s[628]! }
    public var Calls_RatingTitle: String { return self._s[629]! }
    public var Generic_ErrorMoreInfo: String { return self._s[630]! }
    public var Appearance_PreviewReplyText: String { return self._s[631]! }
    public var CheckoutInfo_ShippingInfoPostcodePlaceholder: String { return self._s[632]! }
    public var SharedMedia_CategoryLinks: String { return self._s[633]! }
    public var Calls_Missed: String { return self._s[634]! }
    public var Cache_Photos: String { return self._s[638]! }
    public var GroupPermission_NoAddMembers: String { return self._s[639]! }
    public func Channel_AdminLog_MessageUnpinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[640]!, self._r[640]!, [_0])
    }
    public var Conversation_ShareBotLocationConfirmationTitle: String { return self._s[641]! }
    public var Settings_ProxyDisabled: String { return self._s[642]! }
    public func Settings_ApplyProxyAlertCredentials(_ _1: String, _ _2: String, _ _3: String, _ _4: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[643]!, self._r[643]!, [_1, _2, _3, _4])
    }
    public func Conversation_RestrictedMediaTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[644]!, self._r[644]!, [_0])
    }
    public var Appearance_Title: String { return self._s[645]! }
    public func Time_MonthOfYear_m2(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[647]!, self._r[647]!, [_0])
    }
    public var StickerPacksSettings_ShowStickersButtonHelp: String { return self._s[648]! }
    public var Channel_EditMessageErrorGeneric: String { return self._s[649]! }
    public var Privacy_Calls_IntegrationHelp: String { return self._s[650]! }
    public var Preview_DeletePhoto: String { return self._s[651]! }
    public var PrivacySettings_PrivacyTitle: String { return self._s[652]! }
    public func Conversation_BotInteractiveUrlAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[653]!, self._r[653]!, [_0])
    }
    public var Coub_TapForSound: String { return self._s[655]! }
    public var Map_LocatingError: String { return self._s[656]! }
    public var TwoStepAuth_EmailChangeSuccess: String { return self._s[658]! }
    public var Passport_ForgottenPassword: String { return self._s[659]! }
    public var GroupInfo_InviteLink_RevokeLink: String { return self._s[660]! }
    public var StickerPacksSettings_ArchivedPacks: String { return self._s[661]! }
    public var Login_TermsOfServiceSignupDecline: String { return self._s[663]! }
    public var Channel_Moderator_AccessLevelRevoke: String { return self._s[664]! }
    public var Message_Location: String { return self._s[665]! }
    public var Passport_Identity_NamePlaceholder: String { return self._s[666]! }
    public var Channel_Management_Title: String { return self._s[667]! }
    public var DialogList_SearchSectionDialogs: String { return self._s[669]! }
    public var Compose_NewChannel_Members: String { return self._s[670]! }
    public func DialogList_SingleUploadingFileSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[671]!, self._r[671]!, [_0])
    }
    public var AutoNightTheme_ScheduledFrom: String { return self._s[672]! }
    public var PhotoEditor_WarmthTool: String { return self._s[673]! }
    public var Passport_Language_tr: String { return self._s[674]! }
    public func PUSH_MESSAGE_GAME_SCORE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[675]!, self._r[675]!, [_1, _2, _3])
    }
    public var Login_ResetAccountProtected_Reset: String { return self._s[677]! }
    public var Watch_PhotoView_Title: String { return self._s[678]! }
    public var Passport_Phone_Delete: String { return self._s[679]! }
    public var Undo_ChatDeletedForBothSides: String { return self._s[680]! }
    public var Conversation_EditingMessageMediaEditCurrentPhoto: String { return self._s[681]! }
    public var GroupInfo_Permissions: String { return self._s[682]! }
    public var PasscodeSettings_TurnPasscodeOff: String { return self._s[683]! }
    public var Profile_ShareContactButton: String { return self._s[684]! }
    public var ChatSettings_Other: String { return self._s[685]! }
    public var UserInfo_NotificationsDisabled: String { return self._s[686]! }
    public var CheckoutInfo_ShippingInfoCity: String { return self._s[687]! }
    public var LastSeen_WithinAMonth: String { return self._s[688]! }
    public var Conversation_EncryptionCanceled: String { return self._s[689]! }
    public var MediaPicker_GroupDescription: String { return self._s[690]! }
    public var WebSearch_Images: String { return self._s[691]! }
    public func Channel_Management_PromotedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[692]!, self._r[692]!, [_0])
    }
    public var Message_Photo: String { return self._s[693]! }
    public var PasscodeSettings_HelpBottom: String { return self._s[694]! }
    public var AutoDownloadSettings_VideosTitle: String { return self._s[695]! }
    public var Passport_Identity_AddDriversLicense: String { return self._s[696]! }
    public var TwoStepAuth_EnterPasswordPassword: String { return self._s[697]! }
    public var NotificationsSound_Calypso: String { return self._s[698]! }
    public var Map_Map: String { return self._s[699]! }
    public var CheckoutInfo_ReceiverInfoTitle: String { return self._s[701]! }
    public var ChatSettings_TextSizeUnits: String { return self._s[702]! }
    public var Common_of: String { return self._s[703]! }
    public var Conversation_ForwardContacts: String { return self._s[705]! }
    public func Call_AnsweringWithAccount(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[707]!, self._r[707]!, [_0])
    }
    public var Passport_Language_hy: String { return self._s[708]! }
    public var Notifications_MessageNotificationsHelp: String { return self._s[709]! }
    public var AutoDownloadSettings_Reset: String { return self._s[710]! }
    public var Paint_ClearConfirm: String { return self._s[711]! }
    public var Camera_VideoMode: String { return self._s[712]! }
    public func Conversation_RestrictedStickersTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[713]!, self._r[713]!, [_0])
    }
    public var Privacy_Calls_AlwaysAllow_Placeholder: String { return self._s[714]! }
    public var Conversation_ViewBackground: String { return self._s[715]! }
    public var Passport_Language_el: String { return self._s[716]! }
    public var PhotoEditor_Original: String { return self._s[717]! }
    public var Settings_FAQ_Button: String { return self._s[719]! }
    public var Channel_Setup_PublicNoLink: String { return self._s[721]! }
    public var Conversation_UnsupportedMedia: String { return self._s[722]! }
    public var Conversation_SlideToCancel: String { return self._s[723]! }
    public var Passport_Identity_OneOfTypeInternalPassport: String { return self._s[724]! }
    public var CheckoutInfo_ShippingInfoPostcode: String { return self._s[725]! }
    public var AutoNightTheme_NotAvailable: String { return self._s[726]! }
    public var Common_Create: String { return self._s[727]! }
    public var Settings_ApplyProxyAlertEnable: String { return self._s[728]! }
    public var Localization_ChooseLanguage: String { return self._s[730]! }
    public var Settings_Proxy: String { return self._s[733]! }
    public var Privacy_TopPeersHelp: String { return self._s[734]! }
    public var CheckoutInfo_ShippingInfoCountryPlaceholder: String { return self._s[735]! }
    public var Chat_UnsendMyMessages: String { return self._s[736]! }
    public var TwoStepAuth_ConfirmationAbort: String { return self._s[737]! }
    public func Contacts_AccessDeniedHelpPortrait(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[739]!, self._r[739]!, [_0])
    }
    public var Contacts_SortedByPresence: String { return self._s[740]! }
    public var Passport_Identity_SurnamePlaceholder: String { return self._s[741]! }
    public var Cache_Title: String { return self._s[742]! }
    public func Login_PhoneBannedEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[743]!, self._r[743]!, [_0])
    }
    public var TwoStepAuth_EmailCodeExpired: String { return self._s[744]! }
    public var Channel_Moderator_Title: String { return self._s[745]! }
    public var InstantPage_AutoNightTheme: String { return self._s[747]! }
    public func PUSH_MESSAGE_POLL(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[750]!, self._r[750]!, [_1])
    }
    public var Passport_Scans_Upload: String { return self._s[751]! }
    public var Undo_Undo: String { return self._s[753]! }
    public var Contacts_AccessDeniedHelpON: String { return self._s[754]! }
    public var TwoStepAuth_RemovePassword: String { return self._s[755]! }
    public var Common_Delete: String { return self._s[756]! }
    public var Conversation_ContextMenuDelete: String { return self._s[758]! }
    public var SocksProxySetup_Credentials: String { return self._s[759]! }
    public var PasscodeSettings_AutoLock_Disabled: String { return self._s[761]! }
    public var Passport_Address_OneOfTypeRentalAgreement: String { return self._s[764]! }
    public var Conversation_ShareBotContactConfirmationTitle: String { return self._s[765]! }
    public var Passport_Language_id: String { return self._s[767]! }
    public var WallpaperSearch_ColorTeal: String { return self._s[768]! }
    public var ChannelIntro_Title: String { return self._s[769]! }
    public func Channel_AdminLog_MessageToggleSignaturesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[770]!, self._r[770]!, [_0])
    }
    public var Channel_Info_Description: String { return self._s[772]! }
    public var Stickers_FavoriteStickers: String { return self._s[773]! }
    public var Channel_BanUser_PermissionAddMembers: String { return self._s[774]! }
    public var Notifications_DisplayNamesOnLockScreen: String { return self._s[775]! }
    public var Calls_NoMissedCallsPlacehoder: String { return self._s[776]! }
    public var Notifications_ExceptionsDefaultSound: String { return self._s[777]! }
    public func PUSH_CHANNEL_MESSAGE_POLL(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[778]!, self._r[778]!, [_1])
    }
    public func DialogList_SearchSubtitleFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[779]!, self._r[779]!, [_1, _2])
    }
    public func Channel_AdminLog_MessageRemovedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[780]!, self._r[780]!, [_0])
    }
    public var GroupPermission_Delete: String { return self._s[781]! }
    public var Passport_Language_uk: String { return self._s[782]! }
    public var StickerPack_HideStickers: String { return self._s[784]! }
    public var ChangePhoneNumberNumber_NumberPlaceholder: String { return self._s[785]! }
    public func PUSH_CHAT_MESSAGE_PHOTO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[786]!, self._r[786]!, [_1, _2])
    }
    public var Activity_UploadingVideoMessage: String { return self._s[787]! }
    public func GroupPermission_ApplyAlertText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[788]!, self._r[788]!, [_0])
    }
    public var Channel_TitleInfo: String { return self._s[789]! }
    public var StickerPacksSettings_ArchivedPacks_Info: String { return self._s[790]! }
    public var Settings_CallSettings: String { return self._s[791]! }
    public var Camera_SquareMode: String { return self._s[792]! }
    public var GroupInfo_SharedMediaNone: String { return self._s[793]! }
    public func PUSH_MESSAGE_VIDEO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[794]!, self._r[794]!, [_1])
    }
    public var Bot_GenericBotStatus: String { return self._s[795]! }
    public var Application_Update: String { return self._s[797]! }
    public var Month_ShortJanuary: String { return self._s[798]! }
    public var Contacts_PermissionsKeepDisabled: String { return self._s[799]! }
    public var Channel_AdminLog_BanReadMessages: String { return self._s[800]! }
    public var Settings_AppLanguage_Unofficial: String { return self._s[801]! }
    public var Passport_Address_Street2Placeholder: String { return self._s[802]! }
    public func Map_LiveLocationShortHour(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[803]!, self._r[803]!, [_0])
    }
    public var NetworkUsageSettings_Cellular: String { return self._s[804]! }
    public var Appearance_PreviewOutgoingText: String { return self._s[805]! }
    public var Notifications_PermissionsAllowInSettings: String { return self._s[806]! }
    public var AutoDownloadSettings_OnForAll: String { return self._s[808]! }
    public var Map_Directions: String { return self._s[809]! }
    public var Passport_FieldIdentityTranslationHelp: String { return self._s[811]! }
    public var Appearance_ThemeDay: String { return self._s[812]! }
    public var LogoutOptions_LogOut: String { return self._s[813]! }
    public var Passport_Identity_AddPassport: String { return self._s[815]! }
    public var Call_Message: String { return self._s[816]! }
    public var PhotoEditor_ExposureTool: String { return self._s[817]! }
    public var Passport_FieldOneOf_Delimeter: String { return self._s[819]! }
    public var Channel_AdminLog_CanBanUsers: String { return self._s[821]! }
    public var Appearance_Preview: String { return self._s[822]! }
    public var Compose_ChannelMembers: String { return self._s[823]! }
    public var Conversation_DeleteManyMessages: String { return self._s[824]! }
    public var ReportPeer_ReasonOther_Title: String { return self._s[825]! }
    public var Checkout_ErrorProviderAccountTimeout: String { return self._s[826]! }
    public var TwoStepAuth_ResetAccountConfirmation: String { return self._s[827]! }
    public var Channel_Stickers_CreateYourOwn: String { return self._s[830]! }
    public var Conversation_UpdateTelegram: String { return self._s[831]! }
    public func Notification_PinnedPhotoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[832]!, self._r[832]!, [_0])
    }
    public func PUSH_PINNED_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[833]!, self._r[833]!, [_1])
    }
    public var GroupInfo_Administrators_Title: String { return self._s[834]! }
    public var Privacy_Forwards_PreviewMessageText: String { return self._s[835]! }
    public func PrivacySettings_LastSeenNobodyPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[836]!, self._r[836]!, [_0])
    }
    public var Tour_Title3: String { return self._s[837]! }
    public var Channel_EditAdmin_PermissionInviteSubscribers: String { return self._s[838]! }
    public var Clipboard_SendPhoto: String { return self._s[842]! }
    public var MediaPicker_Videos: String { return self._s[843]! }
    public var Passport_Email_Title: String { return self._s[844]! }
    public func PrivacySettings_LastSeenEverybodyMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[845]!, self._r[845]!, [_0])
    }
    public var StickerPacksSettings_Title: String { return self._s[846]! }
    public var Conversation_MessageDialogDelete: String { return self._s[847]! }
    public var Privacy_Calls_CustomHelp: String { return self._s[849]! }
    public var Message_Wallpaper: String { return self._s[850]! }
    public var MemberSearch_BotSection: String { return self._s[851]! }
    public var GroupInfo_SetSound: String { return self._s[852]! }
    public var Core_ServiceUserStatus: String { return self._s[853]! }
    public var LiveLocationUpdated_JustNow: String { return self._s[854]! }
    public var Call_StatusFailed: String { return self._s[855]! }
    public var TwoStepAuth_SetupPasswordDescription: String { return self._s[856]! }
    public var TwoStepAuth_SetPassword: String { return self._s[857]! }
    public func SocksProxySetup_ProxyStatusPing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[859]!, self._r[859]!, [_0])
    }
    public var Calls_SubmitRating: String { return self._s[860]! }
    public var Profile_Username: String { return self._s[861]! }
    public var Bot_DescriptionTitle: String { return self._s[862]! }
    public var MaskStickerSettings_Title: String { return self._s[863]! }
    public var SharedMedia_CategoryOther: String { return self._s[864]! }
    public var GroupInfo_SetGroupPhoto: String { return self._s[865]! }
    public var Common_NotNow: String { return self._s[866]! }
    public var CallFeedback_IncludeLogsInfo: String { return self._s[867]! }
    public var Map_Location: String { return self._s[868]! }
    public var Invitation_JoinGroup: String { return self._s[869]! }
    public var AutoDownloadSettings_Title: String { return self._s[871]! }
    public var Conversation_DiscardVoiceMessageDescription: String { return self._s[872]! }
    public var Channel_ErrorAddBlocked: String { return self._s[873]! }
    public var Conversation_UnblockUser: String { return self._s[874]! }
    public var Watch_Bot_Restart: String { return self._s[875]! }
    public var TwoStepAuth_Title: String { return self._s[876]! }
    public var Channel_AdminLog_BanSendMessages: String { return self._s[877]! }
    public var Checkout_ShippingMethod: String { return self._s[878]! }
    public var Passport_Identity_OneOfTypeIdentityCard: String { return self._s[879]! }
    public func PUSH_CHAT_MESSAGE_STICKER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[880]!, self._r[880]!, [_1, _2, _3])
    }
    public func Chat_UnsendMyMessagesAlertTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[882]!, self._r[882]!, [_0])
    }
    public func Channel_Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[883]!, self._r[883]!, [_0])
    }
    public var SettingsSearch_Synonyms_Data_AutoplayGifs: String { return self._s[884]! }
    public var AuthSessions_TerminateOtherSessions: String { return self._s[885]! }
    public var Contacts_FailedToSendInvitesMessage: String { return self._s[886]! }
    public var PrivacySettings_TwoStepAuth: String { return self._s[887]! }
    public var SettingsSearch_Synonyms_Privacy_Passcode: String { return self._s[888]! }
    public var Conversation_EditingMessagePanelMedia: String { return self._s[889]! }
    public var Checkout_PaymentMethod_Title: String { return self._s[890]! }
    public var SocksProxySetup_Connection: String { return self._s[891]! }
    public var Group_MessagePhotoRemoved: String { return self._s[892]! }
    public var Channel_Stickers_NotFound: String { return self._s[894]! }
    public var Group_About_Help: String { return self._s[895]! }
    public var Notification_PassportValueProofOfIdentity: String { return self._s[896]! }
    public func ApplyLanguage_ChangeLanguageOfficialText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[898]!, self._r[898]!, [_1])
    }
    public var CheckoutInfo_ShippingInfoStatePlaceholder: String { return self._s[900]! }
    public var Notifications_GroupNotificationsExceptionsHelp: String { return self._s[901]! }
    public var SocksProxySetup_Password: String { return self._s[902]! }
    public var Notifications_PermissionsEnable: String { return self._s[903]! }
    public var TwoStepAuth_ChangeEmail: String { return self._s[905]! }
    public func Channel_AdminLog_MessageInvitedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[906]!, self._r[906]!, [_1])
    }
    public func Time_MonthOfYear_m10(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[908]!, self._r[908]!, [_0])
    }
    public var Passport_Identity_TypeDriversLicense: String { return self._s[909]! }
    public var ArchivedPacksAlert_Title: String { return self._s[910]! }
    public func Time_PreciseDate_m7(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[911]!, self._r[911]!, [_1, _2, _3])
    }
    public var PrivacyLastSeenSettings_GroupsAndChannelsHelp: String { return self._s[912]! }
    public var Privacy_Calls_NeverAllow_Placeholder: String { return self._s[914]! }
    public var Conversation_StatusTyping: String { return self._s[915]! }
    public var Broadcast_AdminLog_EmptyText: String { return self._s[916]! }
    public var Notification_PassportValueProofOfAddress: String { return self._s[917]! }
    public var UserInfo_CreateNewContact: String { return self._s[918]! }
    public var Passport_Identity_FrontSide: String { return self._s[919]! }
    public var Login_PhoneNumberAlreadyAuthorizedSwitch: String { return self._s[920]! }
    public var Calls_CallTabTitle: String { return self._s[921]! }
    public var Channel_AdminLog_ChannelEmptyText: String { return self._s[922]! }
    public func Login_BannedPhoneBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[923]!, self._r[923]!, [_0])
    }
    public var Watch_UserInfo_MuteTitle: String { return self._s[924]! }
    public var SharedMedia_EmptyMusicText: String { return self._s[925]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1minute: String { return self._s[926]! }
    public var Paint_Stickers: String { return self._s[927]! }
    public var Privacy_GroupsAndChannels: String { return self._s[928]! }
    public var UserInfo_AddContact: String { return self._s[930]! }
    public func Conversation_MessageViaUser(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[931]!, self._r[931]!, [_0])
    }
    public var PhoneNumberHelp_ChangeNumber: String { return self._s[933]! }
    public func ChatList_ClearChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[935]!, self._r[935]!, [_0])
    }
    public var DialogList_NoMessagesTitle: String { return self._s[936]! }
    public var EditProfile_NameAndPhotoHelp: String { return self._s[937]! }
    public var BlockedUsers_BlockUser: String { return self._s[938]! }
    public var Notifications_PermissionsOpenSettings: String { return self._s[939]! }
    public var MediaPicker_UngroupDescription: String { return self._s[940]! }
    public var Watch_NoConnection: String { return self._s[941]! }
    public var Month_GenSeptember: String { return self._s[942]! }
    public var Conversation_ViewGroup: String { return self._s[943]! }
    public var Channel_AdminLogFilter_EventsLeavingSubscribers: String { return self._s[946]! }
    public var Privacy_Forwards_AlwaysLink: String { return self._s[947]! }
    public var Passport_FieldOneOf_FinalDelimeter: String { return self._s[948]! }
    public var MediaPicker_CameraRoll: String { return self._s[950]! }
    public var Month_GenAugust: String { return self._s[951]! }
    public var AccessDenied_VideoMessageMicrophone: String { return self._s[952]! }
    public var SharedMedia_EmptyText: String { return self._s[953]! }
    public var Map_ShareLiveLocation: String { return self._s[954]! }
    public var Calls_All: String { return self._s[955]! }
    public var Appearance_ThemeNight: String { return self._s[958]! }
    public var Conversation_HoldForAudio: String { return self._s[959]! }
    public var SettingsSearch_Synonyms_Support: String { return self._s[962]! }
    public var GroupInfo_GroupHistoryHidden: String { return self._s[963]! }
    public var SocksProxySetup_Secret: String { return self._s[964]! }
    public var Channel_BanList_RestrictedTitle: String { return self._s[966]! }
    public var Conversation_Location: String { return self._s[967]! }
    public func AutoDownloadSettings_UpToFor(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[968]!, self._r[968]!, [_0, _1])
    }
    public var ChatSettings_AutoDownloadPhotos: String { return self._s[970]! }
    public var SettingsSearch_Synonyms_Privacy_Title: String { return self._s[971]! }
    public var Notifications_PermissionsText: String { return self._s[972]! }
    public var SettingsSearch_Synonyms_Data_SaveIncomingPhotos: String { return self._s[973]! }
    public var Call_Flip: String { return self._s[974]! }
    public var SocksProxySetup_ProxyStatusConnecting: String { return self._s[975]! }
    public var Channel_EditAdmin_PermissionPinMessages: String { return self._s[977]! }
    public var TwoStepAuth_ReEnterPasswordDescription: String { return self._s[979]! }
    public var Passport_DeletePassportConfirmation: String { return self._s[981]! }
    public var Login_InvalidCodeError: String { return self._s[982]! }
    public var StickerPacksSettings_FeaturedPacks: String { return self._s[983]! }
    public func ChatList_DeleteSecretChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[984]!, self._r[984]!, [_0])
    }
    public func GroupInfo_InvitationLinkAcceptChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[985]!, self._r[985]!, [_0])
    }
    public var Call_CallInProgressTitle: String { return self._s[986]! }
    public var Month_ShortSeptember: String { return self._s[987]! }
    public var Watch_ChannelInfo_Title: String { return self._s[988]! }
    public var ChatList_DeleteSavedMessagesConfirmation: String { return self._s[991]! }
    public var DialogList_PasscodeLockHelp: String { return self._s[992]! }
    public var Notifications_Badge_IncludePublicGroups: String { return self._s[993]! }
    public var Channel_AdminLogFilter_EventsTitle: String { return self._s[994]! }
    public var PhotoEditor_CropReset: String { return self._s[995]! }
    public var Group_Username_CreatePrivateLinkHelp: String { return self._s[997]! }
    public var Channel_Management_LabelEditor: String { return self._s[998]! }
    public var Passport_Identity_LatinNameHelp: String { return self._s[1000]! }
    public var PhotoEditor_HighlightsTool: String { return self._s[1001]! }
    public var UserInfo_Title: String { return self._s[1002]! }
    public var ChatList_HideAction: String { return self._s[1003]! }
    public var AccessDenied_Title: String { return self._s[1004]! }
    public var DialogList_SearchLabel: String { return self._s[1005]! }
    public var Group_Setup_HistoryHidden: String { return self._s[1006]! }
    public var TwoStepAuth_PasswordChangeSuccess: String { return self._s[1007]! }
    public var State_Updating: String { return self._s[1009]! }
    public var Contacts_TabTitle: String { return self._s[1010]! }
    public var Notifications_Badge_CountUnreadMessages: String { return self._s[1012]! }
    public var GroupInfo_GroupHistory: String { return self._s[1013]! }
    public var Conversation_UnsupportedMediaPlaceholder: String { return self._s[1014]! }
    public var Wallpaper_SetColor: String { return self._s[1015]! }
    public var CheckoutInfo_ShippingInfoCountry: String { return self._s[1016]! }
    public var SettingsSearch_Synonyms_SavedMessages: String { return self._s[1017]! }
    public var Passport_Identity_OneOfTypeDriversLicense: String { return self._s[1018]! }
    public var Contacts_NotRegisteredSection: String { return self._s[1019]! }
    public func Time_PreciseDate_m4(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1020]!, self._r[1020]!, [_1, _2, _3])
    }
    public var Paint_Clear: String { return self._s[1021]! }
    public var StickerPacksSettings_ArchivedMasks: String { return self._s[1022]! }
    public var SocksProxySetup_Connecting: String { return self._s[1023]! }
    public var ExplicitContent_AlertChannel: String { return self._s[1024]! }
    public var CreatePoll_AllOptionsAdded: String { return self._s[1025]! }
    public var Conversation_Contact: String { return self._s[1026]! }
    public var Login_CodeExpired: String { return self._s[1027]! }
    public var Passport_DiscardMessageAction: String { return self._s[1028]! }
    public var Channel_AdminLog_MessagePreviousDescription: String { return self._s[1029]! }
    public var Channel_AdminLog_EmptyMessageText: String { return self._s[1030]! }
    public var SettingsSearch_Synonyms_Data_NetworkUsage: String { return self._s[1031]! }
    public var Month_ShortApril: String { return self._s[1032]! }
    public var AuthSessions_CurrentSession: String { return self._s[1033]! }
    public var WallpaperPreview_CropTopText: String { return self._s[1037]! }
    public var PrivacySettings_DeleteAccountIfAwayFor: String { return self._s[1038]! }
    public var CheckoutInfo_ShippingInfoTitle: String { return self._s[1039]! }
    public var Channel_Setup_TypePrivate: String { return self._s[1041]! }
    public var Forward_ChannelReadOnly: String { return self._s[1044]! }
    public var PhotoEditor_CurvesBlue: String { return self._s[1045]! }
    public var UserInfo_BotPrivacy: String { return self._s[1046]! }
    public var Notification_PassportValueEmail: String { return self._s[1047]! }
    public var EmptyGroupInfo_Subtitle: String { return self._s[1048]! }
    public var GroupPermission_NewTitle: String { return self._s[1049]! }
    public var CallFeedback_ReasonDropped: String { return self._s[1050]! }
    public var GroupInfo_Permissions_AddException: String { return self._s[1051]! }
    public var Channel_SignMessages_Help: String { return self._s[1053]! }
    public var Undo_ChatDeleted: String { return self._s[1055]! }
    public var Conversation_ChatBackground: String { return self._s[1056]! }
    public var ChannelMembers_WhoCanAddMembers_Admins: String { return self._s[1057]! }
    public var FastTwoStepSetup_EmailPlaceholder: String { return self._s[1058]! }
    public var Passport_Language_pt: String { return self._s[1059]! }
    public var NotificationsSound_Popcorn: String { return self._s[1062]! }
    public var AutoNightTheme_Disabled: String { return self._s[1063]! }
    public var BlockedUsers_LeavePrefix: String { return self._s[1064]! }
    public var WallpaperPreview_CustomColorTopText: String { return self._s[1065]! }
    public var Contacts_PermissionsSuppressWarningText: String { return self._s[1066]! }
    public var WallpaperSearch_ColorBlue: String { return self._s[1067]! }
    public func CancelResetAccount_TextSMS(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1068]!, self._r[1068]!, [_0])
    }
    public var CheckoutInfo_ErrorNameInvalid: String { return self._s[1069]! }
    public var SocksProxySetup_UseForCalls: String { return self._s[1070]! }
    public var Passport_DeleteDocumentConfirmation: String { return self._s[1072]! }
    public func Conversation_Megabytes(_ _0: Float) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1073]!, self._r[1073]!, ["\(_0)"])
    }
    public var SocksProxySetup_Hostname: String { return self._s[1076]! }
    public var ChatSettings_AutoDownloadSettings_OffForAll: String { return self._s[1077]! }
    public var Compose_NewEncryptedChat: String { return self._s[1078]! }
    public var Login_CodeFloodError: String { return self._s[1079]! }
    public var Calls_TabTitle: String { return self._s[1080]! }
    public var Privacy_ProfilePhoto: String { return self._s[1081]! }
    public var Passport_Language_he: String { return self._s[1082]! }
    public var GroupPermission_Title: String { return self._s[1083]! }
    public func Channel_AdminLog_MessageGroupPreHistoryHidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1084]!, self._r[1084]!, [_0])
    }
    public var GroupPermission_NoChangeInfo: String { return self._s[1085]! }
    public var ChatList_DeleteForCurrentUser: String { return self._s[1086]! }
    public var Tour_Text1: String { return self._s[1087]! }
    public var Month_ShortFebruary: String { return self._s[1088]! }
    public var TwoStepAuth_EmailSkip: String { return self._s[1089]! }
    public var NotificationsSound_Glass: String { return self._s[1090]! }
    public var Appearance_ThemeNightBlue: String { return self._s[1091]! }
    public var CheckoutInfo_Pay: String { return self._s[1092]! }
    public var Invite_LargeRecipientsCountWarning: String { return self._s[1094]! }
    public var Call_CallAgain: String { return self._s[1096]! }
    public var AttachmentMenu_SendAsFile: String { return self._s[1097]! }
    public var AccessDenied_MicrophoneRestricted: String { return self._s[1098]! }
    public var Passport_InvalidPasswordError: String { return self._s[1099]! }
    public var Watch_Message_Game: String { return self._s[1100]! }
    public var Stickers_Install: String { return self._s[1101]! }
    public var PrivacyLastSeenSettings_NeverShareWith: String { return self._s[1102]! }
    public var Passport_Identity_ResidenceCountry: String { return self._s[1104]! }
    public var Notifications_GroupNotificationsHelp: String { return self._s[1105]! }
    public var AuthSessions_OtherSessions: String { return self._s[1106]! }
    public var Channel_Username_Help: String { return self._s[1107]! }
    public var Camera_Title: String { return self._s[1108]! }
    public var GroupInfo_SetGroupPhotoDelete: String { return self._s[1110]! }
    public var Privacy_ProfilePhoto_NeverShareWith_Title: String { return self._s[1111]! }
    public var Channel_AdminLog_SendPolls: String { return self._s[1112]! }
    public var Channel_AdminLog_TitleAllEvents: String { return self._s[1113]! }
    public var Channel_EditAdmin_PermissionInviteMembers: String { return self._s[1114]! }
    public var Contacts_MemberSearchSectionTitleGroup: String { return self._s[1115]! }
    public var Conversation_RestrictedStickers: String { return self._s[1116]! }
    public var Notifications_ExceptionsResetToDefaults: String { return self._s[1118]! }
    public var UserInfo_TelegramCall: String { return self._s[1120]! }
    public var TwoStepAuth_SetupResendEmailCode: String { return self._s[1121]! }
    public var CreatePoll_OptionsHeader: String { return self._s[1122]! }
    public var SettingsSearch_Synonyms_Data_CallsUseLessData: String { return self._s[1123]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Title: String { return self._s[1124]! }
    public var Passport_Identity_EditPersonalDetails: String { return self._s[1125]! }
    public func Time_PreciseDate_m1(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1126]!, self._r[1126]!, [_1, _2, _3])
    }
    public var Settings_SaveEditedPhotos: String { return self._s[1127]! }
    public var TwoStepAuth_ConfirmationTitle: String { return self._s[1128]! }
    public var Privacy_GroupsAndChannels_NeverAllow_Title: String { return self._s[1129]! }
    public var Conversation_MessageDialogRetry: String { return self._s[1130]! }
    public var Conversation_DiscardVoiceMessageAction: String { return self._s[1131]! }
    public var Group_Setup_TypeHeader: String { return self._s[1132]! }
    public var Paint_RecentStickers: String { return self._s[1133]! }
    public var PhotoEditor_GrainTool: String { return self._s[1134]! }
    public var CheckoutInfo_ShippingInfoState: String { return self._s[1135]! }
    public var EmptyGroupInfo_Line4: String { return self._s[1136]! }
    public var Watch_AuthRequired: String { return self._s[1138]! }
    public func Passport_Email_UseTelegramEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1139]!, self._r[1139]!, [_0])
    }
    public var Conversation_EncryptedDescriptionTitle: String { return self._s[1140]! }
    public var ChannelIntro_Text: String { return self._s[1141]! }
    public var DialogList_DeleteBotConfirmation: String { return self._s[1142]! }
    public var GroupPermission_NoSendMedia: String { return self._s[1143]! }
    public var Calls_AddTab: String { return self._s[1144]! }
    public var Message_ReplyActionButtonShowReceipt: String { return self._s[1145]! }
    public var Channel_AdminLog_EmptyFilterText: String { return self._s[1146]! }
    public var Notification_MessageLifetime1d: String { return self._s[1147]! }
    public var Notifications_ChannelNotificationsExceptionsHelp: String { return self._s[1148]! }
    public var Channel_BanUser_PermissionsHeader: String { return self._s[1149]! }
    public var Passport_Identity_GenderFemale: String { return self._s[1150]! }
    public var BlockedUsers_BlockTitle: String { return self._s[1151]! }
    public func PUSH_CHANNEL_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1152]!, self._r[1152]!, [_1])
    }
    public var Weekday_Yesterday: String { return self._s[1153]! }
    public var WallpaperSearch_ColorBlack: String { return self._s[1154]! }
    public var ChatList_ArchiveAction: String { return self._s[1155]! }
    public var AutoNightTheme_Scheduled: String { return self._s[1156]! }
    public func Login_PhoneGenericEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1157]!, self._r[1157]!, [_1, _2, _3, _4, _5, _6])
    }
    public var PrivacyPolicy_DeclineDeleteNow: String { return self._s[1158]! }
    public func PUSH_CHAT_JOINED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1159]!, self._r[1159]!, [_1, _2])
    }
    public var CreatePoll_Create: String { return self._s[1160]! }
    public var Channel_Members_AddBannedErrorAdmin: String { return self._s[1161]! }
    public func Notification_CallFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1162]!, self._r[1162]!, [_1, _2])
    }
    public var Checkout_ErrorProviderAccountInvalid: String { return self._s[1163]! }
    public var Notifications_InAppNotificationsSounds: String { return self._s[1165]! }
    public func PUSH_PINNED_GAME_SCORE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1166]!, self._r[1166]!, [_1])
    }
    public var Preview_OpenInInstagram: String { return self._s[1167]! }
    public var Notification_MessageLifetimeRemovedOutgoing: String { return self._s[1168]! }
    public func PUSH_CHAT_ADD_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1169]!, self._r[1169]!, [_1, _2, _3])
    }
    public func Passport_PrivacyPolicy(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1170]!, self._r[1170]!, [_1, _2])
    }
    public var Channel_AdminLog_InfoPanelAlertTitle: String { return self._s[1171]! }
    public var NetworkUsageSettings_TotalSection: String { return self._s[1172]! }
    public var Channel_Setup_TypePrivateHelp: String { return self._s[1173]! }
    public func PUSH_CHAT_MESSAGE_POLL(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1174]!, self._r[1174]!, [_1, _2, _3])
    }
    public var Privacy_GroupsAndChannels_NeverAllow_Placeholder: String { return self._s[1176]! }
    public var FastTwoStepSetup_HintSection: String { return self._s[1177]! }
    public var Wallpaper_PhotoLibrary: String { return self._s[1178]! }
    public var TwoStepAuth_SetupResendEmailCodeAlert: String { return self._s[1179]! }
    public var Gif_NoGifsFound: String { return self._s[1180]! }
    public var Watch_LastSeen_WithinAMonth: String { return self._s[1181]! }
    public var GroupInfo_ActionPromote: String { return self._s[1182]! }
    public var PasscodeSettings_SimplePasscode: String { return self._s[1183]! }
    public var GroupInfo_Permissions_Title: String { return self._s[1184]! }
    public var Permissions_ContactsText_v0: String { return self._s[1185]! }
    public var SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedPublicGroups: String { return self._s[1186]! }
    public var PrivacySettings_DataSettingsHelp: String { return self._s[1189]! }
    public var Passport_FieldEmailHelp: String { return self._s[1190]! }
    public var Passport_Identity_GenderPlaceholder: String { return self._s[1191]! }
    public var Weekday_ShortSaturday: String { return self._s[1192]! }
    public var ContactInfo_PhoneLabelMain: String { return self._s[1193]! }
    public var Watch_Conversation_UserInfo: String { return self._s[1194]! }
    public var CheckoutInfo_ShippingInfoCityPlaceholder: String { return self._s[1195]! }
    public var PrivacyLastSeenSettings_Title: String { return self._s[1196]! }
    public var Conversation_ShareBotLocationConfirmation: String { return self._s[1197]! }
    public var PhotoEditor_VignetteTool: String { return self._s[1198]! }
    public var Passport_Address_Street1Placeholder: String { return self._s[1199]! }
    public var Passport_Language_et: String { return self._s[1200]! }
    public var Passport_Language_bg: String { return self._s[1202]! }
    public var Stickers_NoStickersFound: String { return self._s[1204]! }
    public func PUSH_CHANNEL_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1206]!, self._r[1206]!, [_1, _2])
    }
    public var Settings_About: String { return self._s[1207]! }
    public func Channel_AdminLog_MessageRestricted(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1208]!, self._r[1208]!, [_0, _1, _2])
    }
    public var KeyCommand_NewMessage: String { return self._s[1210]! }
    public var Group_ErrorAddBlocked: String { return self._s[1211]! }
    public func Message_PaymentSent(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1212]!, self._r[1212]!, [_0])
    }
    public var Map_LocationTitle: String { return self._s[1213]! }
    public var CallSettings_UseLessDataLongDescription: String { return self._s[1214]! }
    public var Cache_ClearProgress: String { return self._s[1215]! }
    public func Channel_Management_ErrorNotMember(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1216]!, self._r[1216]!, [_0])
    }
    public var GroupRemoved_AddToGroup: String { return self._s[1217]! }
    public var Passport_UpdateRequiredError: String { return self._s[1218]! }
    public func PUSH_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1219]!, self._r[1219]!, [_1])
    }
    public var Notifications_PermissionsSuppressWarningText: String { return self._s[1221]! }
    public var Passport_Identity_MainPageHelp: String { return self._s[1222]! }
    public var Conversation_StatusKickedFromGroup: String { return self._s[1223]! }
    public var Passport_Language_ka: String { return self._s[1224]! }
    public var Call_Decline: String { return self._s[1225]! }
    public var SocksProxySetup_ProxyEnabled: String { return self._s[1226]! }
    public func AuthCode_Alert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1229]!, self._r[1229]!, [_0])
    }
    public var CallFeedback_Send: String { return self._s[1230]! }
    public func Channel_AdminLog_MessagePromotedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1231]!, self._r[1231]!, [_1, _2])
    }
    public var Passport_Phone_UseTelegramNumberHelp: String { return self._s[1232]! }
    public var SettingsSearch_Synonyms_Data_Title: String { return self._s[1234]! }
    public var Passport_DeletePassport: String { return self._s[1235]! }
    public var Privacy_Calls_P2PAlways: String { return self._s[1236]! }
    public var Month_ShortDecember: String { return self._s[1237]! }
    public var Channel_AdminLog_CanEditMessages: String { return self._s[1239]! }
    public func Contacts_AccessDeniedHelpLandscape(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1240]!, self._r[1240]!, [_0])
    }
    public var Channel_Stickers_Searching: String { return self._s[1241]! }
    public var Conversation_EncryptedDescription1: String { return self._s[1242]! }
    public var Conversation_EncryptedDescription2: String { return self._s[1243]! }
    public var Conversation_EncryptedDescription3: String { return self._s[1244]! }
    public var PhotoEditor_SharpenTool: String { return self._s[1245]! }
    public var Conversation_EncryptedDescription4: String { return self._s[1247]! }
    public var Channel_Members_AddMembers: String { return self._s[1248]! }
    public var Wallpaper_Search: String { return self._s[1249]! }
    public var Weekday_Friday: String { return self._s[1250]! }
    public var Privacy_ContactsSync: String { return self._s[1251]! }
    public var SettingsSearch_Synonyms_Privacy_Data_ContactsReset: String { return self._s[1252]! }
    public var ApplyLanguage_ChangeLanguageAction: String { return self._s[1253]! }
    public func Channel_Management_RestrictedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1254]!, self._r[1254]!, [_0])
    }
    public var GroupInfo_Permissions_Removed: String { return self._s[1255]! }
    public var Passport_Identity_GenderMale: String { return self._s[1256]! }
    public func Call_StatusBar(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1257]!, self._r[1257]!, [_0])
    }
    public var Notifications_PermissionsKeepDisabled: String { return self._s[1258]! }
    public var Conversation_JumpToDate: String { return self._s[1259]! }
    public var Contacts_GlobalSearch: String { return self._s[1260]! }
    public var AutoDownloadSettings_ResetHelp: String { return self._s[1261]! }
    public var SettingsSearch_Synonyms_FAQ: String { return self._s[1262]! }
    public var Profile_MessageLifetime1d: String { return self._s[1263]! }
    public func MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1264]!, self._r[1264]!, [_1, _2])
    }
    public var StickerPack_BuiltinPackName: String { return self._s[1267]! }
    public func PUSH_CHAT_MESSAGE_AUDIO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1268]!, self._r[1268]!, [_1, _2])
    }
    public var Passport_InfoTitle: String { return self._s[1270]! }
    public var Notifications_PermissionsUnreachableText: String { return self._s[1271]! }
    public func NetworkUsageSettings_CellularUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1275]!, self._r[1275]!, [_0])
    }
    public func PUSH_CHAT_MESSAGE_GEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1276]!, self._r[1276]!, [_1, _2])
    }
    public var Passport_Address_TypePassportRegistrationUploadScan: String { return self._s[1277]! }
    public var Profile_BotInfo: String { return self._s[1278]! }
    public var Watch_Compose_CreateMessage: String { return self._s[1279]! }
    public var AutoDownloadSettings_VoiceMessagesInfo: String { return self._s[1280]! }
    public var Month_ShortNovember: String { return self._s[1281]! }
    public var Wallpaper_SetCustomBackground: String { return self._s[1282]! }
    public var Passport_Identity_TranslationsHelp: String { return self._s[1283]! }
    public var NotificationsSound_Chime: String { return self._s[1284]! }
    public var Passport_Language_ko: String { return self._s[1286]! }
    public var InviteText_URL: String { return self._s[1287]! }
    public var TextFormat_Monospace: String { return self._s[1288]! }
    public func Time_PreciseDate_m11(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1289]!, self._r[1289]!, [_1, _2, _3])
    }
    public func Login_WillSendSms(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1290]!, self._r[1290]!, [_0])
    }
    public func Watch_Time_ShortWeekdayAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1291]!, self._r[1291]!, [_1, _2])
    }
    public var Passport_InfoLearnMore: String { return self._s[1293]! }
    public var TwoStepAuth_EmailPlaceholder: String { return self._s[1294]! }
    public var Passport_Identity_AddIdentityCard: String { return self._s[1295]! }
    public var Your_card_has_expired: String { return self._s[1296]! }
    public var StickerPacksSettings_StickerPacksSection: String { return self._s[1297]! }
    public var GroupInfo_InviteLink_Help: String { return self._s[1298]! }
    public var Conversation_Report: String { return self._s[1302]! }
    public var Notifications_MessageNotificationsSound: String { return self._s[1303]! }
    public var Notification_MessageLifetime1m: String { return self._s[1304]! }
    public var Privacy_ContactsTitle: String { return self._s[1305]! }
    public var Conversation_ShareMyContactInfo: String { return self._s[1306]! }
    public var ChannelMembers_WhoCanAddMembersAdminsHelp: String { return self._s[1307]! }
    public var Channel_Members_Title: String { return self._s[1308]! }
    public var Map_OpenInWaze: String { return self._s[1309]! }
    public var Login_PhoneBannedError: String { return self._s[1310]! }
    public func LiveLocationUpdated_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1311]!, self._r[1311]!, [_0])
    }
    public var Group_Management_AddModeratorHelp: String { return self._s[1312]! }
    public var AutoDownloadSettings_WifiTitle: String { return self._s[1313]! }
    public var Common_OK: String { return self._s[1314]! }
    public var Passport_Address_TypeBankStatementUploadScan: String { return self._s[1315]! }
    public var Cache_Music: String { return self._s[1316]! }
    public var SettingsSearch_Synonyms_EditProfile_PhoneNumber: String { return self._s[1317]! }
    public var PasscodeSettings_UnlockWithTouchId: String { return self._s[1318]! }
    public var TwoStepAuth_HintPlaceholder: String { return self._s[1319]! }
    public func PUSH_PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1320]!, self._r[1320]!, [_1])
    }
    public func Passport_RequestHeader(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1321]!, self._r[1321]!, [_0])
    }
    public var Watch_MessageView_ViewOnPhone: String { return self._s[1323]! }
    public var Privacy_Calls_CustomShareHelp: String { return self._s[1324]! }
    public var ChangePhoneNumberNumber_Title: String { return self._s[1326]! }
    public var State_ConnectingToProxyInfo: String { return self._s[1327]! }
    public var Message_VideoMessage: String { return self._s[1329]! }
    public var ChannelInfo_DeleteChannel: String { return self._s[1330]! }
    public var ContactInfo_PhoneLabelOther: String { return self._s[1331]! }
    public var Channel_EditAdmin_CannotEdit: String { return self._s[1332]! }
    public var Passport_DeleteAddressConfirmation: String { return self._s[1333]! }
    public var WallpaperPreview_SwipeBottomText: String { return self._s[1334]! }
    public var Activity_RecordingAudio: String { return self._s[1335]! }
    public var SettingsSearch_Synonyms_Watch: String { return self._s[1336]! }
    public var PasscodeSettings_TryAgainIn1Minute: String { return self._s[1337]! }
    public func Notification_ChangedGroupName(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1339]!, self._r[1339]!, [_0, _1])
    }
    public func EmptyGroupInfo_Line1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1343]!, self._r[1343]!, [_0])
    }
    public var Conversation_ApplyLocalization: String { return self._s[1344]! }
    public var UserInfo_AddPhone: String { return self._s[1345]! }
    public var Map_ShareLiveLocationHelp: String { return self._s[1346]! }
    public func Passport_Identity_NativeNameGenericHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1347]!, self._r[1347]!, [_0])
    }
    public var Passport_Scans: String { return self._s[1349]! }
    public var BlockedUsers_Unblock: String { return self._s[1350]! }
    public func PUSH_ENCRYPTION_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1351]!, self._r[1351]!, [_1])
    }
    public var Channel_Management_LabelCreator: String { return self._s[1352]! }
    public var SettingsSearch_Synonyms_EditProfile_Bio: String { return self._s[1353]! }
    public var Passport_Identity_NativeNameGenericTitle: String { return self._s[1354]! }
    public func Login_EmailPhoneBody(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1355]!, self._r[1355]!, [_0, _1, _2])
    }
    public var Login_PhoneNumberHelp: String { return self._s[1356]! }
    public var LastSeen_ALongTimeAgo: String { return self._s[1357]! }
    public var Channel_AdminLog_CanPinMessages: String { return self._s[1358]! }
    public var ChannelIntro_CreateChannel: String { return self._s[1359]! }
    public var Conversation_UnreadMessages: String { return self._s[1360]! }
    public var SettingsSearch_Synonyms_Stickers_ArchivedPacks: String { return self._s[1361]! }
    public var Channel_AdminLog_EmptyText: String { return self._s[1362]! }
    public var Notification_GroupActivated: String { return self._s[1363]! }
    public var NotificationSettings_ContactJoinedInfo: String { return self._s[1364]! }
    public func Notification_PinnedContactMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1365]!, self._r[1365]!, [_0])
    }
    public func DownloadingStatus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1366]!, self._r[1366]!, [_0, _1])
    }
    public var GroupInfo_ConvertToSupergroup: String { return self._s[1368]! }
    public func PrivacyPolicy_AgeVerificationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1369]!, self._r[1369]!, [_0])
    }
    public var Undo_DeletedChannel: String { return self._s[1370]! }
    public var CallFeedback_AddComment: String { return self._s[1371]! }
    public var Document_TargetConfirmationFormat: String { return self._s[1372]! }
    public func Call_StatusOngoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1373]!, self._r[1373]!, [_0])
    }
    public var LogoutOptions_SetPasscodeTitle: String { return self._s[1374]! }
    public func PUSH_CHAT_MESSAGE_GAME_SCORE(_ _1: String, _ _2: String, _ _3: String, _ _4: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1375]!, self._r[1375]!, [_1, _2, _3, _4])
    }
    public var Contacts_SortByName: String { return self._s[1376]! }
    public var SettingsSearch_Synonyms_Privacy_Forwards: String { return self._s[1377]! }
    public func CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1379]!, self._r[1379]!, [_1, _2, _3])
    }
    public var Conversation_ClearSelfHistory: String { return self._s[1380]! }
    public var Checkout_NewCard_PostcodePlaceholder: String { return self._s[1381]! }
    public var Stickers_SuggestNone: String { return self._s[1382]! }
    public var ChatSettings_Cache: String { return self._s[1383]! }
    public var Settings_SaveIncomingPhotos: String { return self._s[1384]! }
    public var Media_ShareThisPhoto: String { return self._s[1385]! }
    public var InfoPlist_NSContactsUsageDescription: String { return self._s[1386]! }
    public var Conversation_ContextMenuCopyLink: String { return self._s[1387]! }
    public var PrivacyPolicy_AgeVerificationTitle: String { return self._s[1388]! }
    public var SettingsSearch_Synonyms_Stickers_Masks: String { return self._s[1389]! }
    public var TwoStepAuth_SetupPasswordEnterPasswordNew: String { return self._s[1390]! }
    public var Permissions_CellularDataTitle_v0: String { return self._s[1391]! }
    public var WallpaperSearch_ColorWhite: String { return self._s[1393]! }
    public var Channel_AdminLog_DefaultRestrictionsUpdated: String { return self._s[1394]! }
    public var Conversation_ErrorInaccessibleMessage: String { return self._s[1395]! }
    public var Map_OpenIn: String { return self._s[1396]! }
    public func PUSH_PHONE_CALL_MISSED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1399]!, self._r[1399]!, [_1])
    }
    public func ChannelInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1400]!, self._r[1400]!, [_0])
    }
    public var MessagePoll_LabelClosed: String { return self._s[1401]! }
    public var GroupPermission_PermissionGloballyDisabled: String { return self._s[1403]! }
    public var Passport_Identity_MiddleNamePlaceholder: String { return self._s[1404]! }
    public var UserInfo_FirstNamePlaceholder: String { return self._s[1405]! }
    public var PrivacyLastSeenSettings_WhoCanSeeMyTimestamp: String { return self._s[1406]! }
    public var Login_SelectCountry_Title: String { return self._s[1407]! }
    public var Channel_EditAdmin_PermissionBanUsers: String { return self._s[1408]! }
    public var Channel_AdminLog_ChangeInfo: String { return self._s[1409]! }
    public var Watch_Suggestion_BRB: String { return self._s[1410]! }
    public var Passport_Identity_EditIdentityCard: String { return self._s[1411]! }
    public var Contacts_PermissionsTitle: String { return self._s[1412]! }
    public var Conversation_RestrictedInline: String { return self._s[1413]! }
    public var StickerPack_ViewPack: String { return self._s[1415]! }
    public func Update_AppVersion(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1416]!, self._r[1416]!, [_0])
    }
    public var Compose_NewChannel: String { return self._s[1418]! }
    public var ChatSettings_AutoDownloadSettings_TypePhoto: String { return self._s[1421]! }
    public var Channel_Info_Stickers: String { return self._s[1423]! }
    public var AutoNightTheme_PreferredTheme: String { return self._s[1424]! }
    public var PrivacyPolicy_AgeVerificationAgree: String { return self._s[1425]! }
    public var Passport_DeletePersonalDetails: String { return self._s[1426]! }
    public var LogoutOptions_AddAccountTitle: String { return self._s[1427]! }
    public var Conversation_SearchNoResults: String { return self._s[1429]! }
    public var MessagePoll_LabelAnonymous: String { return self._s[1430]! }
    public var Channel_Members_AddAdminErrorNotAMember: String { return self._s[1431]! }
    public var Login_Code: String { return self._s[1432]! }
    public var Watch_Suggestion_WhatsUp: String { return self._s[1433]! }
    public var Weekday_ShortThursday: String { return self._s[1434]! }
    public var Resolve_ErrorNotFound: String { return self._s[1436]! }
    public var LastSeen_Offline: String { return self._s[1437]! }
    public var GroupPermission_AddMembersNotAvailable: String { return self._s[1438]! }
    public var Privacy_Calls_AlwaysAllow_Title: String { return self._s[1439]! }
    public var GroupInfo_Title: String { return self._s[1440]! }
    public var NotificationsSound_Note: String { return self._s[1441]! }
    public var Conversation_EditingMessagePanelTitle: String { return self._s[1442]! }
    public var Watch_Message_Poll: String { return self._s[1443]! }
    public var Privacy_Calls: String { return self._s[1444]! }
    public var Month_ShortAugust: String { return self._s[1445]! }
    public var TwoStepAuth_SetPasswordHelp: String { return self._s[1446]! }
    public var Notifications_Reset: String { return self._s[1447]! }
    public var Conversation_Pin: String { return self._s[1448]! }
    public var Passport_Language_lv: String { return self._s[1449]! }
    public var BlockedUsers_Info: String { return self._s[1450]! }
    public var SettingsSearch_Synonyms_Data_AutoplayVideos: String { return self._s[1452]! }
    public var Watch_Conversation_Unblock: String { return self._s[1454]! }
    public func Time_MonthOfYear_m9(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1455]!, self._r[1455]!, [_0])
    }
    public var CloudStorage_Title: String { return self._s[1456]! }
    public var GroupInfo_DeleteAndExitConfirmation: String { return self._s[1457]! }
    public func NetworkUsageSettings_WifiUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1458]!, self._r[1458]!, [_0])
    }
    public var Channel_AdminLogFilter_AdminsTitle: String { return self._s[1459]! }
    public var Watch_Suggestion_OnMyWay: String { return self._s[1460]! }
    public var TwoStepAuth_RecoveryEmailTitle: String { return self._s[1461]! }
    public var Passport_Address_EditBankStatement: String { return self._s[1462]! }
    public var ChatSettings_DownloadInBackgroundInfo: String { return self._s[1463]! }
    public var ShareMenu_Comment: String { return self._s[1464]! }
    public var Permissions_ContactsTitle_v0: String { return self._s[1465]! }
    public var Notifications_PermissionsTitle: String { return self._s[1466]! }
    public var GroupPermission_NoSendLinks: String { return self._s[1467]! }
    public var Privacy_Forwards_NeverAllow_Title: String { return self._s[1468]! }
    public var Settings_Support: String { return self._s[1469]! }
    public var Notifications_ChannelNotificationsSound: String { return self._s[1470]! }
    public var SettingsSearch_Synonyms_Data_AutoDownloadReset: String { return self._s[1471]! }
    public var Privacy_Forwards_Preview: String { return self._s[1472]! }
    public var GroupPermission_ApplyAlertAction: String { return self._s[1473]! }
    public var Watch_Stickers_StickerPacks: String { return self._s[1474]! }
    public var Common_Select: String { return self._s[1476]! }
    public var CheckoutInfo_ErrorEmailInvalid: String { return self._s[1477]! }
    public var WallpaperSearch_ColorGray: String { return self._s[1479]! }
    public var ChatAdmins_AllMembersAreAdminsOffHelp: String { return self._s[1480]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5hours: String { return self._s[1481]! }
    public var Appearance_PreviewReplyAuthor: String { return self._s[1482]! }
    public var TwoStepAuth_RecoveryTitle: String { return self._s[1483]! }
    public var Widget_AuthRequired: String { return self._s[1484]! }
    public var Camera_FlashOn: String { return self._s[1485]! }
    public var Channel_Stickers_NotFoundHelp: String { return self._s[1486]! }
    public var Watch_Suggestion_OK: String { return self._s[1487]! }
    public func Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1489]!, self._r[1489]!, [_0])
    }
    public func Notification_PinnedLiveLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1491]!, self._r[1491]!, [_0])
    }
    public var DialogList_AdLabel: String { return self._s[1492]! }
    public var WatchRemote_NotificationText: String { return self._s[1493]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsAlert: String { return self._s[1494]! }
    public var Conversation_ReportSpam: String { return self._s[1495]! }
    public var SettingsSearch_Synonyms_Privacy_Data_TopPeers: String { return self._s[1496]! }
    public var Settings_LogoutConfirmationTitle: String { return self._s[1498]! }
    public var PhoneLabel_Title: String { return self._s[1499]! }
    public var Passport_Address_EditRentalAgreement: String { return self._s[1500]! }
    public var Settings_ChangePhoneNumber: String { return self._s[1501]! }
    public var Notifications_ExceptionsTitle: String { return self._s[1502]! }
    public var Notifications_AlertTones: String { return self._s[1503]! }
    public var Call_ReportIncludeLogDescription: String { return self._s[1504]! }
    public var SettingsSearch_Synonyms_Notifications_ResetAllNotifications: String { return self._s[1505]! }
    public var AutoDownloadSettings_PrivateChats: String { return self._s[1506]! }
    public var TwoStepAuth_AddHintTitle: String { return self._s[1508]! }
    public var ReportPeer_ReasonOther: String { return self._s[1509]! }
    public var KeyCommand_ScrollDown: String { return self._s[1511]! }
    public func Login_BannedPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1512]!, self._r[1512]!, [_0])
    }
    public var NetworkUsageSettings_MediaVideoDataSection: String { return self._s[1513]! }
    public var ChannelInfo_DeleteGroupConfirmation: String { return self._s[1514]! }
    public var AuthSessions_LogOut: String { return self._s[1515]! }
    public var Passport_Identity_TypeInternalPassport: String { return self._s[1516]! }
    public var ChatSettings_AutoDownloadVoiceMessages: String { return self._s[1517]! }
    public var Passport_Phone_Title: String { return self._s[1518]! }
    public var Settings_PhoneNumber: String { return self._s[1519]! }
    public var NotificationsSound_Alert: String { return self._s[1520]! }
    public var WebSearch_SearchNoResults: String { return self._s[1521]! }
    public var Privacy_ProfilePhoto_AlwaysShareWith_Title: String { return self._s[1523]! }
    public var LogoutOptions_AlternativeOptionsSection: String { return self._s[1524]! }
    public var SettingsSearch_Synonyms_Passport: String { return self._s[1525]! }
    public var PhotoEditor_CurvesTool: String { return self._s[1526]! }
    public var Checkout_PaymentMethod: String { return self._s[1528]! }
    public func PUSH_CHAT_ADD_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1529]!, self._r[1529]!, [_1, _2])
    }
    public var Contacts_AccessDeniedError: String { return self._s[1530]! }
    public var Camera_PhotoMode: String { return self._s[1533]! }
    public var Passport_Address_AddUtilityBill: String { return self._s[1534]! }
    public var CallSettings_OnMobile: String { return self._s[1535]! }
    public var Tour_Text2: String { return self._s[1536]! }
    public func PUSH_CHAT_MESSAGE_ROUND(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1537]!, self._r[1537]!, [_1, _2])
    }
    public var DialogList_EncryptionProcessing: String { return self._s[1539]! }
    public var Permissions_Skip: String { return self._s[1540]! }
    public var SecretImage_Title: String { return self._s[1541]! }
    public var Watch_MessageView_Title: String { return self._s[1542]! }
    public var AttachmentMenu_Poll: String { return self._s[1543]! }
    public func Notification_GroupInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1544]!, self._r[1544]!, [_0])
    }
    public var Notification_CallCanceled: String { return self._s[1545]! }
    public var WallpaperPreview_Title: String { return self._s[1546]! }
    public var Privacy_PaymentsClear_PaymentInfo: String { return self._s[1547]! }
    public var Settings_ProxyConnecting: String { return self._s[1548]! }
    public var Settings_CheckPhoneNumberText: String { return self._s[1550]! }
    public var Profile_MessageLifetime5s: String { return self._s[1551]! }
    public var Username_InvalidCharacters: String { return self._s[1552]! }
    public var WallpaperPreview_CropBottomText: String { return self._s[1553]! }
    public var AutoDownloadSettings_LimitBySize: String { return self._s[1554]! }
    public var Settings_AddAccount: String { return self._s[1555]! }
    public var Notification_CreatedChannel: String { return self._s[1558]! }
    public func PUSH_CHAT_DELETE_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1559]!, self._r[1559]!, [_1, _2, _3])
    }
    public var Passcode_AppLockedAlert: String { return self._s[1561]! }
    public var Contacts_TopSection: String { return self._s[1562]! }
    public func Time_MonthOfYear_m6(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1563]!, self._r[1563]!, [_0])
    }
    public var ReportPeer_ReasonSpam: String { return self._s[1564]! }
    public var UserInfo_TapToCall: String { return self._s[1565]! }
    public var Conversation_ForwardAuthorHiddenTooltip: String { return self._s[1567]! }
    public var AutoDownloadSettings_DataUsageCustom: String { return self._s[1568]! }
    public var Common_Search: String { return self._s[1569]! }
    public var AuthSessions_IncompleteAttemptsInfo: String { return self._s[1570]! }
    public var Message_InvoiceLabel: String { return self._s[1571]! }
    public var Conversation_InputTextPlaceholder: String { return self._s[1572]! }
    public var NetworkUsageSettings_MediaImageDataSection: String { return self._s[1573]! }
    public func Passport_Address_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1574]!, self._r[1574]!, [_0])
    }
    public var Conversation_Info: String { return self._s[1575]! }
    public var Login_InfoDeletePhoto: String { return self._s[1576]! }
    public var Passport_Language_vi: String { return self._s[1578]! }
    public var Conversation_Search: String { return self._s[1579]! }
    public var DialogList_DeleteBotConversationConfirmation: String { return self._s[1580]! }
    public var ReportPeer_ReasonPornography: String { return self._s[1581]! }
    public var AutoDownloadSettings_PhotosTitle: String { return self._s[1582]! }
    public var Conversation_SendMessageErrorGroupRestricted: String { return self._s[1583]! }
    public var Map_LiveLocationGroupDescription: String { return self._s[1584]! }
    public var Channel_Setup_TypeHeader: String { return self._s[1585]! }
    public var AuthSessions_LoggedIn: String { return self._s[1586]! }
    public var Privacy_Forwards_AlwaysAllow_Title: String { return self._s[1587]! }
    public var Login_SmsRequestState3: String { return self._s[1588]! }
    public var Passport_Address_EditUtilityBill: String { return self._s[1589]! }
    public var Appearance_ReduceMotionInfo: String { return self._s[1590]! }
    public var Channel_Edit_LinkItem: String { return self._s[1591]! }
    public var Privacy_Calls_P2PNever: String { return self._s[1592]! }
    public var Conversation_AddToReadingList: String { return self._s[1594]! }
    public var Message_Animation: String { return self._s[1595]! }
    public var Conversation_DefaultRestrictedMedia: String { return self._s[1596]! }
    public var Map_Unknown: String { return self._s[1597]! }
    public var AutoDownloadSettings_LastDelimeter: String { return self._s[1598]! }
    public func PUSH_PINNED_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1599]!, self._r[1599]!, [_1, _2])
    }
    public func Passport_FieldOneOf_Or(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1600]!, self._r[1600]!, [_1, _2])
    }
    public var Call_StatusRequesting: String { return self._s[1601]! }
    public var Conversation_SecretChatContextBotAlert: String { return self._s[1602]! }
    public var SocksProxySetup_ProxyStatusChecking: String { return self._s[1603]! }
    public func PUSH_CHAT_MESSAGE_DOC(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1604]!, self._r[1604]!, [_1, _2])
    }
    public var Weekday_Monday: String { return self._s[1605]! }
    public var Update_Skip: String { return self._s[1606]! }
    public var Group_Username_RemoveExistingUsernamesInfo: String { return self._s[1607]! }
    public var Message_PinnedPollMessage: String { return self._s[1608]! }
    public var BlockedUsers_Title: String { return self._s[1609]! }
    public func PUSH_CHANNEL_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1610]!, self._r[1610]!, [_1])
    }
    public var Username_CheckingUsername: String { return self._s[1611]! }
    public var NotificationsSound_Bell: String { return self._s[1612]! }
    public var Conversation_SendMessageErrorFlood: String { return self._s[1613]! }
    public func Notification_PinnedLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1614]!, self._r[1614]!, [_0])
    }
    public var SettingsSearch_Synonyms_Notifications_DisplayNamesOnLockScreen: String { return self._s[1615]! }
    public var ChannelMembers_ChannelAdminsTitle: String { return self._s[1616]! }
    public var ChatSettings_Groups: String { return self._s[1617]! }
    public var Your_card_was_declined: String { return self._s[1618]! }
    public var TwoStepAuth_EnterPasswordHelp: String { return self._s[1620]! }
    public var ChatList_Unmute: String { return self._s[1621]! }
    public var PhotoEditor_CurvesAll: String { return self._s[1622]! }
    public var Weekday_ShortTuesday: String { return self._s[1623]! }
    public var DialogList_Read: String { return self._s[1624]! }
    public var ChannelMembers_WhoCanAddMembers_AllMembers: String { return self._s[1625]! }
    public var Passport_Identity_Gender: String { return self._s[1626]! }
    public func Target_ShareGameConfirmationPrivate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1627]!, self._r[1627]!, [_0])
    }
    public var Target_SelectGroup: String { return self._s[1628]! }
    public func DialogList_EncryptedChatStartedIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1630]!, self._r[1630]!, [_0])
    }
    public var Passport_Language_en: String { return self._s[1631]! }
    public var AutoDownloadSettings_AutodownloadPhotos: String { return self._s[1632]! }
    public var Channel_Username_CreatePublicLinkHelp: String { return self._s[1633]! }
    public var Login_CancelPhoneVerificationContinue: String { return self._s[1634]! }
    public var Checkout_NewCard_PaymentCard: String { return self._s[1636]! }
    public var Login_InfoHelp: String { return self._s[1637]! }
    public var Contacts_PermissionsSuppressWarningTitle: String { return self._s[1638]! }
    public var SettingsSearch_Synonyms_Stickers_FeaturedPacks: String { return self._s[1639]! }
    public var SocksProxySetup_AddProxy: String { return self._s[1642]! }
    public var CreatePoll_Title: String { return self._s[1643]! }
    public var SettingsSearch_Synonyms_Privacy_Data_SecretChatLinkPreview: String { return self._s[1644]! }
    public var PasscodeSettings_SimplePasscodeHelp: String { return self._s[1645]! }
    public var UserInfo_GroupsInCommon: String { return self._s[1646]! }
    public var Call_AudioRouteHide: String { return self._s[1647]! }
    public var ContactInfo_PhoneLabelMobile: String { return self._s[1649]! }
    public func ChatList_LeaveGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1650]!, self._r[1650]!, [_0])
    }
    public var TextFormat_Bold: String { return self._s[1651]! }
    public var FastTwoStepSetup_EmailSection: String { return self._s[1652]! }
    public var Notifications_Title: String { return self._s[1653]! }
    public var Group_Username_InvalidTooShort: String { return self._s[1654]! }
    public var Channel_ErrorAddTooMuch: String { return self._s[1655]! }
    public func DialogList_MultipleTypingSuffix(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1656]!, self._r[1656]!, ["\(_0)"])
    }
    public var Stickers_SuggestAdded: String { return self._s[1658]! }
    public var Login_CountryCode: String { return self._s[1659]! }
    public var ChatSettings_AutoPlayVideos: String { return self._s[1660]! }
    public var Map_GetDirections: String { return self._s[1661]! }
    public var Login_PhoneFloodError: String { return self._s[1662]! }
    public func Time_MonthOfYear_m3(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1663]!, self._r[1663]!, [_0])
    }
    public var Settings_SetUsername: String { return self._s[1665]! }
    public var Notification_GroupInviterSelf: String { return self._s[1666]! }
    public var InstantPage_TapToOpenLink: String { return self._s[1667]! }
    public func Notification_ChannelInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1668]!, self._r[1668]!, [_0])
    }
    public var Watch_Suggestion_TalkLater: String { return self._s[1669]! }
    public var SecretChat_Title: String { return self._s[1670]! }
    public var Group_UpgradeNoticeText1: String { return self._s[1671]! }
    public var AuthSessions_Title: String { return self._s[1672]! }
    public var PhotoEditor_CropAuto: String { return self._s[1673]! }
    public var Channel_About_Title: String { return self._s[1674]! }
    public var FastTwoStepSetup_EmailHelp: String { return self._s[1675]! }
    public func Conversation_Bytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1677]!, self._r[1677]!, ["\(_0)"])
    }
    public var Conversation_PinMessageAlert_OnlyPin: String { return self._s[1679]! }
    public var Group_Setup_HistoryVisibleHelp: String { return self._s[1680]! }
    public func PUSH_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1681]!, self._r[1681]!, [_1])
    }
    public func SharedMedia_SearchNoResultsDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1683]!, self._r[1683]!, [_0])
    }
    public func TwoStepAuth_RecoveryEmailUnavailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1684]!, self._r[1684]!, [_0])
    }
    public var Privacy_PaymentsClearInfoHelp: String { return self._s[1685]! }
    public var Presence_online: String { return self._s[1687]! }
    public var PasscodeSettings_Title: String { return self._s[1688]! }
    public var Passport_Identity_ExpiryDatePlaceholder: String { return self._s[1689]! }
    public var Web_OpenExternal: String { return self._s[1690]! }
    public var AutoDownloadSettings_AutoDownload: String { return self._s[1692]! }
    public func AutoNightTheme_AutomaticHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1693]!, self._r[1693]!, [_0])
    }
    public var FastTwoStepSetup_PasswordConfirmationPlaceholder: String { return self._s[1694]! }
    public var Map_YouAreHere: String { return self._s[1695]! }
    public func AuthSessions_Message(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1696]!, self._r[1696]!, [_0])
    }
    public func ChatList_DeleteChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1697]!, self._r[1697]!, [_0])
    }
    public var PrivacyLastSeenSettings_AlwaysShareWith: String { return self._s[1698]! }
    public var Target_InviteToGroupErrorAlreadyInvited: String { return self._s[1699]! }
    public func AuthSessions_AppUnofficial(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1700]!, self._r[1700]!, [_0])
    }
    public func DialogList_LiveLocationSharingTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1701]!, self._r[1701]!, [_0])
    }
    public var SocksProxySetup_Username: String { return self._s[1702]! }
    public var Bot_Start: String { return self._s[1703]! }
    public func Channel_AdminLog_EmptyFilterQueryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1704]!, self._r[1704]!, [_0])
    }
    public func Channel_AdminLog_MessagePinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1705]!, self._r[1705]!, [_0])
    }
    public var Contacts_SortByPresence: String { return self._s[1706]! }
    public var Conversation_DiscardVoiceMessageTitle: String { return self._s[1708]! }
    public func PUSH_CHAT_CREATED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1709]!, self._r[1709]!, [_1, _2])
    }
    public func PrivacySettings_LastSeenContactsMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1710]!, self._r[1710]!, [_0])
    }
    public var Passport_Email_EnterOtherEmail: String { return self._s[1711]! }
    public var Login_InfoAvatarPhoto: String { return self._s[1712]! }
    public var Privacy_PaymentsClear_ShippingInfo: String { return self._s[1713]! }
    public var Tour_Title4: String { return self._s[1714]! }
    public var Passport_Identity_Translation: String { return self._s[1715]! }
    public var SettingsSearch_Synonyms_Notifications_ContactJoined: String { return self._s[1716]! }
    public var Login_TermsOfServiceLabel: String { return self._s[1718]! }
    public var Passport_Language_it: String { return self._s[1719]! }
    public var KeyCommand_JumpToNextUnreadChat: String { return self._s[1720]! }
    public var Passport_Identity_SelfieHelp: String { return self._s[1721]! }
    public var Conversation_ClearAll: String { return self._s[1723]! }
    public var TwoStepAuth_FloodError: String { return self._s[1725]! }
    public func PUSH_CHANNEL_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1726]!, self._r[1726]!, [_1])
    }
    public var Paint_Delete: String { return self._s[1727]! }
    public var LogoutOptions_SetPasscodeText: String { return self._s[1728]! }
    public func Passport_AcceptHelp(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1729]!, self._r[1729]!, [_1, _2])
    }
    public var Message_PinnedAudioMessage: String { return self._s[1730]! }
    public func Watch_Time_ShortTodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1731]!, self._r[1731]!, [_0])
    }
    public var Notification_Mute1hMin: String { return self._s[1732]! }
    public var Notifications_GroupNotificationsSound: String { return self._s[1733]! }
    public var SocksProxySetup_ShareProxyList: String { return self._s[1734]! }
    public var Conversation_MessageEditedLabel: String { return self._s[1735]! }
    public var Notification_Exceptions_AlwaysOff: String { return self._s[1736]! }
    public func Channel_AdminLog_MessageAdmin(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1737]!, self._r[1737]!, [_0, _1, _2])
    }
    public var NetworkUsageSettings_ResetStats: String { return self._s[1738]! }
    public func PUSH_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1739]!, self._r[1739]!, [_1])
    }
    public var AccessDenied_LocationTracking: String { return self._s[1740]! }
    public var DataUpgrade_Running: String { return self._s[1741]! }
    public var Month_GenOctober: String { return self._s[1742]! }
    public var GroupInfo_InviteLink_RevokeAlert_Revoke: String { return self._s[1743]! }
    public var EnterPasscode_EnterPasscode: String { return self._s[1744]! }
    public var MediaPicker_TimerTooltip: String { return self._s[1746]! }
    public var SharedMedia_TitleAll: String { return self._s[1747]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsExceptions: String { return self._s[1750]! }
    public var Conversation_RestrictedMedia: String { return self._s[1751]! }
    public var AccessDenied_PhotosRestricted: String { return self._s[1752]! }
    public var Privacy_Forwards_WhoCanForward: String { return self._s[1754]! }
    public var ChangePhoneNumberCode_Called: String { return self._s[1755]! }
    public func Notification_PinnedDocumentMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1756]!, self._r[1756]!, [_0])
    }
    public var Conversation_SavedMessages: String { return self._s[1759]! }
    public var Your_cards_expiration_month_is_invalid: String { return self._s[1761]! }
    public var FastTwoStepSetup_PasswordPlaceholder: String { return self._s[1762]! }
    public func Target_ShareGameConfirmationGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1764]!, self._r[1764]!, [_0])
    }
    public var ReportPeer_AlertSuccess: String { return self._s[1765]! }
    public var PhotoEditor_CropAspectRatioOriginal: String { return self._s[1766]! }
    public func InstantPage_RelatedArticleAuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1767]!, self._r[1767]!, [_1, _2])
    }
    public var Checkout_PasswordEntry_Title: String { return self._s[1768]! }
    public var PhotoEditor_FadeTool: String { return self._s[1769]! }
    public var Privacy_ContactsReset: String { return self._s[1770]! }
    public func Channel_AdminLog_MessageRestrictedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1772]!, self._r[1772]!, [_0])
    }
    public var Message_PinnedVideoMessage: String { return self._s[1773]! }
    public var ChatList_Mute: String { return self._s[1774]! }
    public var Permissions_CellularDataText_v0: String { return self._s[1775]! }
    public var ShareMenu_SelectChats: String { return self._s[1777]! }
    public var MusicPlayer_VoiceNote: String { return self._s[1778]! }
    public var Conversation_RestrictedText: String { return self._s[1779]! }
    public var SettingsSearch_Synonyms_Privacy_Data_DeleteDrafts: String { return self._s[1780]! }
    public var TwoStepAuth_DisableSuccess: String { return self._s[1781]! }
    public var Cache_Videos: String { return self._s[1782]! }
    public var FeatureDisabled_Oops: String { return self._s[1784]! }
    public var Passport_Address_PostcodePlaceholder: String { return self._s[1785]! }
    public var Stickers_GroupStickersHelp: String { return self._s[1786]! }
    public var GroupPermission_NoSendPolls: String { return self._s[1787]! }
    public var Message_VideoExpired: String { return self._s[1789]! }
    public var Notifications_Badge: String { return self._s[1790]! }
    public var GroupInfo_GroupHistoryVisible: String { return self._s[1791]! }
    public var CreatePoll_OptionPlaceholder: String { return self._s[1792]! }
    public var Username_InvalidTooShort: String { return self._s[1793]! }
    public var EnterPasscode_EnterNewPasscodeChange: String { return self._s[1794]! }
    public var Channel_AdminLog_PinMessages: String { return self._s[1795]! }
    public func Notification_MessageLifetimeRemoved(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1796]!, self._r[1796]!, [_1])
    }
    public var Permissions_SiriAllowInSettings_v0: String { return self._s[1797]! }
    public var Conversation_DefaultRestrictedText: String { return self._s[1798]! }
    public var SharedMedia_CategoryDocs: String { return self._s[1801]! }
    public func PUSH_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1802]!, self._r[1802]!, [_1])
    }
    public var Privacy_Forwards_NeverLink: String { return self._s[1804]! }
    public func Notification_MessageLifetimeChangedOutgoing(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1805]!, self._r[1805]!, [_1])
    }
    public var CheckoutInfo_ErrorShippingNotAvailable: String { return self._s[1806]! }
    public func Time_MonthOfYear_m12(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1807]!, self._r[1807]!, [_0])
    }
    public var ChatSettings_PrivateChats: String { return self._s[1808]! }
    public var SettingsSearch_Synonyms_EditProfile_Logout: String { return self._s[1809]! }
    public var Conversation_PrivateMessageLinkCopied: String { return self._s[1810]! }
    public var Channel_UpdatePhotoItem: String { return self._s[1811]! }
    public var GroupInfo_LeftStatus: String { return self._s[1812]! }
    public var Watch_MessageView_Forward: String { return self._s[1814]! }
    public var ReportPeer_ReasonChildAbuse: String { return self._s[1815]! }
    public var Cache_ClearEmpty: String { return self._s[1817]! }
    public var Localization_LanguageName: String { return self._s[1818]! }
    public var WebSearch_GIFs: String { return self._s[1819]! }
    public var Notifications_DisplayNamesOnLockScreenInfoWithLink: String { return self._s[1820]! }
    public var Username_InvalidStartsWithNumber: String { return self._s[1821]! }
    public var Common_Back: String { return self._s[1822]! }
    public var Passport_Identity_DateOfBirthPlaceholder: String { return self._s[1823]! }
    public func PUSH_CHANNEL_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1824]!, self._r[1824]!, [_1, _2])
    }
    public var Passport_Email_Help: String { return self._s[1825]! }
    public var Watch_Conversation_Reply: String { return self._s[1827]! }
    public var Conversation_EditingMessageMediaChange: String { return self._s[1829]! }
    public var Passport_Identity_IssueDatePlaceholder: String { return self._s[1830]! }
    public var Channel_BanUser_Unban: String { return self._s[1832]! }
    public var Channel_EditAdmin_PermissionPostMessages: String { return self._s[1833]! }
    public var Group_Username_CreatePublicLinkHelp: String { return self._s[1834]! }
    public var TwoStepAuth_ConfirmEmailCodePlaceholder: String { return self._s[1836]! }
    public var Passport_Identity_Name: String { return self._s[1837]! }
    public var GroupRemoved_ViewUserInfo: String { return self._s[1838]! }
    public var Conversation_BlockUser: String { return self._s[1839]! }
    public var Month_GenJanuary: String { return self._s[1840]! }
    public var ChatSettings_TextSize: String { return self._s[1841]! }
    public var Notification_PassportValuePhone: String { return self._s[1842]! }
    public var Passport_Language_ne: String { return self._s[1843]! }
    public var Notification_CallBack: String { return self._s[1844]! }
    public var TwoStepAuth_EmailHelp: String { return self._s[1845]! }
    public func Time_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1846]!, self._r[1846]!, [_0])
    }
    public var Channel_Info_Management: String { return self._s[1847]! }
    public var Passport_FieldIdentityUploadHelp: String { return self._s[1848]! }
    public var Stickers_FrequentlyUsed: String { return self._s[1849]! }
    public var Channel_BanUser_PermissionSendMessages: String { return self._s[1850]! }
    public var Passport_Address_OneOfTypeUtilityBill: String { return self._s[1852]! }
    public func LOCAL_CHANNEL_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1853]!, self._r[1853]!, [_1, "\(_2)"])
    }
    public var Passport_Address_EditResidentialAddress: String { return self._s[1854]! }
    public var PrivacyPolicy_DeclineTitle: String { return self._s[1855]! }
    public var CreatePoll_TextHeader: String { return self._s[1856]! }
    public func Checkout_SavePasswordTimeoutAndTouchId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1857]!, self._r[1857]!, [_0])
    }
    public var PhotoEditor_QualityMedium: String { return self._s[1858]! }
    public var InfoPlist_NSMicrophoneUsageDescription: String { return self._s[1859]! }
    public var Conversation_StatusKickedFromChannel: String { return self._s[1861]! }
    public var CheckoutInfo_ReceiverInfoName: String { return self._s[1862]! }
    public var Group_ErrorSendRestrictedStickers: String { return self._s[1863]! }
    public func Conversation_RestrictedInlineTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1864]!, self._r[1864]!, [_0])
    }
    public var Conversation_LinkDialogOpen: String { return self._s[1866]! }
    public var Settings_Username: String { return self._s[1867]! }
    public var Wallpaper_Wallpaper: String { return self._s[1869]! }
    public var SocksProxySetup_UseProxy: String { return self._s[1871]! }
    public var UserInfo_ShareMyContactInfo: String { return self._s[1872]! }
    public var MessageTimer_Forever: String { return self._s[1873]! }
    public var Privacy_Calls_WhoCanCallMe: String { return self._s[1874]! }
    public var PhotoEditor_DiscardChanges: String { return self._s[1875]! }
    public var AuthSessions_TerminateOtherSessionsHelp: String { return self._s[1876]! }
    public var Passport_Language_da: String { return self._s[1877]! }
    public var SocksProxySetup_PortPlaceholder: String { return self._s[1878]! }
    public func SecretGIF_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1879]!, self._r[1879]!, [_0])
    }
    public var Passport_Address_EditPassportRegistration: String { return self._s[1880]! }
    public func Channel_AdminLog_MessageChangedGroupAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1882]!, self._r[1882]!, [_0])
    }
    public var Passport_Identity_ResidenceCountryPlaceholder: String { return self._s[1884]! }
    public var Conversation_SearchByName_Prefix: String { return self._s[1885]! }
    public var Conversation_PinnedPoll: String { return self._s[1886]! }
    public var Conversation_EmptyGifPanelPlaceholder: String { return self._s[1887]! }
    public func PUSH_ENCRYPTION_ACCEPT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1888]!, self._r[1888]!, [_1])
    }
    public var WallpaperSearch_ColorPurple: String { return self._s[1889]! }
    public var Cache_ByPeerHeader: String { return self._s[1890]! }
    public func Conversation_EncryptedPlaceholderTitleIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1891]!, self._r[1891]!, [_0])
    }
    public var ChatSettings_AutoDownloadDocuments: String { return self._s[1892]! }
    public var Notification_PinnedMessage: String { return self._s[1895]! }
    public var Contacts_SortBy: String { return self._s[1897]! }
    public func PUSH_CHANNEL_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1898]!, self._r[1898]!, [_1])
    }
    public func PUSH_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1900]!, self._r[1900]!, [_1, _2])
    }
    public var Call_EncryptionKey_Title: String { return self._s[1901]! }
    public var Watch_UserInfo_Service: String { return self._s[1902]! }
    public var SettingsSearch_Synonyms_Data_SaveEditedPhotos: String { return self._s[1904]! }
    public var Conversation_Unpin: String { return self._s[1906]! }
    public var CancelResetAccount_Title: String { return self._s[1907]! }
    public var Map_LiveLocationFor15Minutes: String { return self._s[1908]! }
    public func Time_PreciseDate_m8(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1910]!, self._r[1910]!, [_1, _2, _3])
    }
    public var Group_Members_AddMemberBotErrorNotAllowed: String { return self._s[1911]! }
    public var CallSettings_Title: String { return self._s[1912]! }
    public var SettingsSearch_Synonyms_Appearance_ChatBackground: String { return self._s[1913]! }
    public var PasscodeSettings_EncryptDataHelp: String { return self._s[1915]! }
    public var AutoDownloadSettings_Contacts: String { return self._s[1916]! }
    public var Passport_Identity_DocumentDetails: String { return self._s[1917]! }
    public var LoginPassword_PasswordHelp: String { return self._s[1918]! }
    public var SettingsSearch_Synonyms_Data_AutoDownloadUsingWifi: String { return self._s[1919]! }
    public var PrivacyLastSeenSettings_CustomShareSettings_Delete: String { return self._s[1920]! }
    public var Checkout_TotalPaidAmount: String { return self._s[1921]! }
    public func FileSize_KB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1922]!, self._r[1922]!, [_0])
    }
    public var PasscodeSettings_ChangePasscode: String { return self._s[1923]! }
    public var Conversation_SecretLinkPreviewAlert: String { return self._s[1925]! }
    public var Privacy_SecretChatsLinkPreviews: String { return self._s[1926]! }
    public func PUSH_CHANNEL_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1927]!, self._r[1927]!, [_1])
    }
    public var Contacts_InviteFriends: String { return self._s[1929]! }
    public var Map_ChooseLocationTitle: String { return self._s[1930]! }
    public var Conversation_StopPoll: String { return self._s[1932]! }
    public func WebSearch_SearchNoResultsDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1933]!, self._r[1933]!, [_0])
    }
    public var Call_Camera: String { return self._s[1934]! }
    public var LogoutOptions_ChangePhoneNumberTitle: String { return self._s[1935]! }
    public var Calls_RatingFeedback: String { return self._s[1936]! }
    public var GroupInfo_BroadcastListNamePlaceholder: String { return self._s[1937]! }
    public var NotificationsSound_Pulse: String { return self._s[1938]! }
    public var Watch_LastSeen_Lately: String { return self._s[1939]! }
    public var Widget_NoUsers: String { return self._s[1942]! }
    public var Conversation_UnvotePoll: String { return self._s[1943]! }
    public var SettingsSearch_Synonyms_Privacy_ProfilePhoto: String { return self._s[1945]! }
    public var Privacy_ProfilePhoto_WhoCanSeeMyPhoto: String { return self._s[1946]! }
    public var NotificationsSound_Circles: String { return self._s[1947]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Title: String { return self._s[1949]! }
    public var TwoStepAuth_RecoveryCodeExpired: String { return self._s[1950]! }
    public var Proxy_TooltipUnavailable: String { return self._s[1951]! }
    public var Passport_Identity_CountryPlaceholder: String { return self._s[1953]! }
    public var Conversation_FileDropbox: String { return self._s[1955]! }
    public var Notifications_ExceptionsUnmuted: String { return self._s[1956]! }
    public var Tour_Text3: String { return self._s[1958]! }
    public var Login_ResetAccountProtected_Title: String { return self._s[1960]! }
    public var GroupPermission_NoSendMessages: String { return self._s[1961]! }
    public var WallpaperSearch_ColorTitle: String { return self._s[1962]! }
    public var ChatAdmins_AllMembersAreAdminsOnHelp: String { return self._s[1963]! }
    public func Conversation_LiveLocationYouAnd(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1965]!, self._r[1965]!, [_0])
    }
    public var GroupInfo_AddParticipantTitle: String { return self._s[1966]! }
    public var Checkout_ShippingOption_Title: String { return self._s[1967]! }
    public var ChatSettings_AutoDownloadTitle: String { return self._s[1968]! }
    public func DialogList_SingleTypingSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1969]!, self._r[1969]!, [_0])
    }
    public func ChatSettings_AutoDownloadSettings_TypeVideo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1970]!, self._r[1970]!, [_0])
    }
    public var PrivacyLastSeenSettings_NeverShareWith_Placeholder: String { return self._s[1971]! }
    public var AutoDownloadSettings_Photos: String { return self._s[1973]! }
    public var Appearance_PreviewIncomingText: String { return self._s[1974]! }
    public var ChannelInfo_ConfirmLeave: String { return self._s[1975]! }
    public var MediaPicker_MomentsDateRangeSameMonthYearFormat: String { return self._s[1976]! }
    public var Passport_Identity_DocumentNumberPlaceholder: String { return self._s[1977]! }
    public var Channel_AdminLogFilter_EventsNewMembers: String { return self._s[1978]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5minutes: String { return self._s[1979]! }
    public var GroupInfo_SetGroupPhotoStop: String { return self._s[1980]! }
    public var Notification_SecretChatScreenshot: String { return self._s[1981]! }
    public var AccessDenied_Wallpapers: String { return self._s[1982]! }
    public var Passport_Address_City: String { return self._s[1984]! }
    public var InfoPlist_NSPhotoLibraryAddUsageDescription: String { return self._s[1985]! }
    public var SocksProxySetup_SecretPlaceholder: String { return self._s[1986]! }
    public var AccessDenied_LocationDisabled: String { return self._s[1987]! }
    public var SocksProxySetup_HostnamePlaceholder: String { return self._s[1989]! }
    public var GroupInfo_Sound: String { return self._s[1990]! }
    public var Stickers_RemoveFromFavorites: String { return self._s[1991]! }
    public var Contacts_Title: String { return self._s[1992]! }
    public var Passport_Language_fr: String { return self._s[1993]! }
    public var Notifications_ResetAllNotifications: String { return self._s[1994]! }
    public var PrivacySettings_SecurityTitle: String { return self._s[1997]! }
    public var Checkout_NewCard_Title: String { return self._s[1998]! }
    public var Login_HaveNotReceivedCodeInternal: String { return self._s[1999]! }
    public var Conversation_ForwardChats: String { return self._s[2000]! }
    public var Settings_FAQ: String { return self._s[2003]! }
    public var AutoDownloadSettings_DocumentsTitle: String { return self._s[2004]! }
    public var Conversation_ContextMenuForward: String { return self._s[2005]! }
    public var PrivacyPolicy_Title: String { return self._s[2010]! }
    public var Notifications_TextTone: String { return self._s[2011]! }
    public var Profile_CreateNewContact: String { return self._s[2012]! }
    public var Call_Speaker: String { return self._s[2014]! }
    public var AutoNightTheme_AutomaticSection: String { return self._s[2015]! }
    public var Channel_Username_InvalidCharacters: String { return self._s[2017]! }
    public func Channel_AdminLog_MessageChangedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2018]!, self._r[2018]!, [_0])
    }
    public var AutoDownloadSettings_AutodownloadFiles: String { return self._s[2019]! }
    public var PrivacySettings_LastSeenTitle: String { return self._s[2020]! }
    public var Channel_AdminLog_CanInviteUsers: String { return self._s[2021]! }
    public var SettingsSearch_Synonyms_Privacy_Data_ClearPaymentsInfo: String { return self._s[2022]! }
    public var Conversation_MessageDeliveryFailed: String { return self._s[2023]! }
    public var Watch_ChatList_NoConversationsText: String { return self._s[2024]! }
    public var Bot_Unblock: String { return self._s[2025]! }
    public var TextFormat_Italic: String { return self._s[2026]! }
    public var WallpaperSearch_ColorPink: String { return self._s[2027]! }
    public var Weekday_Wednesday: String { return self._s[2028]! }
    public var Settings_About_Help: String { return self._s[2029]! }
    public var SearchImages_Title: String { return self._s[2030]! }
    public var Conversation_ClousStorageInfo_Description1: String { return self._s[2031]! }
    public var ExplicitContent_AlertTitle: String { return self._s[2032]! }
    public func Time_PreciseDate_m5(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2033]!, self._r[2033]!, [_1, _2, _3])
    }
    public var Weekday_Thursday: String { return self._s[2034]! }
    public var Channel_BanUser_PermissionChangeGroupInfo: String { return self._s[2035]! }
    public var Channel_Members_AddMembersHelp: String { return self._s[2036]! }
    public func Checkout_SavePasswordTimeout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2037]!, self._r[2037]!, [_0])
    }
    public var SettingsSearch_Synonyms_Notifications_InAppNotificationsVibrate: String { return self._s[2038]! }
    public var Passport_RequestedInformation: String { return self._s[2039]! }
    public var Login_PhoneAndCountryHelp: String { return self._s[2040]! }
    public var Conversation_EncryptionProcessing: String { return self._s[2042]! }
    public var Notifications_PermissionsSuppressWarningTitle: String { return self._s[2043]! }
    public var PhotoEditor_EnhanceTool: String { return self._s[2045]! }
    public var Channel_Setup_Title: String { return self._s[2046]! }
    public var Conversation_SearchPlaceholder: String { return self._s[2047]! }
    public var AccessDenied_LocationAlwaysDenied: String { return self._s[2048]! }
    public var Checkout_ErrorGeneric: String { return self._s[2049]! }
    public var Passport_Language_hu: String { return self._s[2050]! }
    public func Passport_Identity_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2052]!, self._r[2052]!, [_0])
    }
    public func PUSH_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2055]!, self._r[2055]!, [_1])
    }
    public var Conversation_CloudStorageInfo_Title: String { return self._s[2056]! }
    public var PhotoEditor_CropAspectRatioSquare: String { return self._s[2057]! }
    public func Notification_Exceptions_MutedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2058]!, self._r[2058]!, [_0])
    }
    public var Conversation_ClearPrivateHistory: String { return self._s[2059]! }
    public var ContactInfo_PhoneLabelHome: String { return self._s[2060]! }
    public var PrivacySettings_LastSeenContacts: String { return self._s[2061]! }
    public func ChangePhone_ErrorOccupied(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2062]!, self._r[2062]!, [_0])
    }
    public var Passport_Language_cs: String { return self._s[2063]! }
    public var Message_PinnedAnimationMessage: String { return self._s[2065]! }
    public var Passport_Identity_ReverseSideHelp: String { return self._s[2067]! }
    public var SettingsSearch_Synonyms_Data_Storage_Title: String { return self._s[2068]! }
    public var SettingsSearch_Synonyms_Privacy_PasscodeAndTouchId: String { return self._s[2070]! }
    public var Embed_PlayingInPIP: String { return self._s[2071]! }
    public var AutoNightTheme_ScheduleSection: String { return self._s[2072]! }
    public func Call_EmojiDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2073]!, self._r[2073]!, [_0])
    }
    public var MediaPicker_LivePhotoDescription: String { return self._s[2074]! }
    public func Channel_AdminLog_MessageRestrictedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2075]!, self._r[2075]!, [_1])
    }
    public var Notification_PaymentSent: String { return self._s[2076]! }
    public var PhotoEditor_CurvesGreen: String { return self._s[2077]! }
    public var SaveIncomingPhotosSettings_Title: String { return self._s[2078]! }
    public var NotificationSettings_ShowNotificationsAllAccounts: String { return self._s[2079]! }
    public func PUSH_MESSAGE_SCREENSHOT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2082]!, self._r[2082]!, [_1])
    }
    public func PUSH_MESSAGE_PHOTO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2083]!, self._r[2083]!, [_1])
    }
    public func ApplyLanguage_UnsufficientDataText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2084]!, self._r[2084]!, [_1])
    }
    public var NetworkUsageSettings_CallDataSection: String { return self._s[2086]! }
    public var PasscodeSettings_HelpTop: String { return self._s[2087]! }
    public var Passport_Address_TypeRentalAgreement: String { return self._s[2088]! }
    public var ReportPeer_ReasonOther_Placeholder: String { return self._s[2089]! }
    public var CheckoutInfo_ErrorPhoneInvalid: String { return self._s[2090]! }
    public var Call_Accept: String { return self._s[2092]! }
    public var GroupRemoved_RemoveInfo: String { return self._s[2093]! }
    public var Month_GenMarch: String { return self._s[2095]! }
    public var PhotoEditor_ShadowsTool: String { return self._s[2096]! }
    public var LoginPassword_Title: String { return self._s[2097]! }
    public var Call_End: String { return self._s[2098]! }
    public var Watch_Conversation_GroupInfo: String { return self._s[2099]! }
    public var CallSettings_Always: String { return self._s[2100]! }
    public var CallFeedback_Success: String { return self._s[2101]! }
    public var TwoStepAuth_SetupHint: String { return self._s[2102]! }
    public var ConversationProfile_UsersTooMuchError: String { return self._s[2103]! }
    public var Login_PhoneTitle: String { return self._s[2104]! }
    public var Passport_FieldPhoneHelp: String { return self._s[2105]! }
    public var Weekday_ShortSunday: String { return self._s[2106]! }
    public var Passport_InfoFAQ_URL: String { return self._s[2107]! }
    public var ContactInfo_Job: String { return self._s[2109]! }
    public var UserInfo_InviteBotToGroup: String { return self._s[2110]! }
    public var TwoStepAuth_PasswordRemovePassportConfirmation: String { return self._s[2111]! }
    public var SettingsSearch_Synonyms_Notifications_InAppNotificationsPreview: String { return self._s[2112]! }
    public var Passport_DeletePersonalDetailsConfirmation: String { return self._s[2113]! }
    public var CallFeedback_ReasonNoise: String { return self._s[2114]! }
    public var Passport_Identity_AddInternalPassport: String { return self._s[2116]! }
    public var MediaPicker_AddCaption: String { return self._s[2117]! }
    public var CallSettings_TabIconDescription: String { return self._s[2118]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow: String { return self._s[2119]! }
    public var Passport_Identity_TypePersonalDetails: String { return self._s[2120]! }
    public var DialogList_SearchSectionRecent: String { return self._s[2121]! }
    public var PrivacyPolicy_DeclineMessage: String { return self._s[2122]! }
    public var LogoutOptions_ClearCacheText: String { return self._s[2125]! }
    public var LastSeen_WithinAWeek: String { return self._s[2126]! }
    public var ChannelMembers_GroupAdminsTitle: String { return self._s[2127]! }
    public var Conversation_CloudStorage_ChatStatus: String { return self._s[2129]! }
    public var Passport_Address_TypeResidentialAddress: String { return self._s[2130]! }
    public var Conversation_StatusLeftGroup: String { return self._s[2131]! }
    public var SocksProxySetup_ProxyDetailsTitle: String { return self._s[2132]! }
    public var SettingsSearch_Synonyms_Calls_Title: String { return self._s[2134]! }
    public var GroupPermission_AddSuccess: String { return self._s[2135]! }
    public var PhotoEditor_BlurToolRadial: String { return self._s[2137]! }
    public var Conversation_ContextMenuCopy: String { return self._s[2138]! }
    public var AccessDenied_CallMicrophone: String { return self._s[2139]! }
    public func Time_PreciseDate_m2(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2140]!, self._r[2140]!, [_1, _2, _3])
    }
    public var Login_InvalidFirstNameError: String { return self._s[2141]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOn: String { return self._s[2142]! }
    public var Checkout_PaymentMethod_New: String { return self._s[2143]! }
    public var ShareMenu_CopyShareLinkGame: String { return self._s[2144]! }
    public var PhotoEditor_QualityTool: String { return self._s[2145]! }
    public var Login_SendCodeViaSms: String { return self._s[2146]! }
    public var SettingsSearch_Synonyms_Privacy_DeleteAccountIfAwayFor: String { return self._s[2147]! }
    public var Login_EmailNotConfiguredError: String { return self._s[2148]! }
    public var SocksProxySetup_Status: String { return self._s[2149]! }
    public var PrivacyPolicy_Accept: String { return self._s[2150]! }
    public var Notifications_ExceptionsMessagePlaceholder: String { return self._s[2151]! }
    public func PUSH_CHAT_MESSAGE_TEXT(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2152]!, self._r[2152]!, [_1, _2, _3])
    }
    public var InfoPlist_NSLocationAlwaysUsageDescription: String { return self._s[2153]! }
    public var AutoNightTheme_Automatic: String { return self._s[2154]! }
    public var Channel_Username_InvalidStartsWithNumber: String { return self._s[2155]! }
    public var Privacy_ContactsSyncHelp: String { return self._s[2156]! }
    public var Cache_Help: String { return self._s[2157]! }
    public var Passport_Language_fa: String { return self._s[2158]! }
    public var Login_ResetAccountProtected_TimerTitle: String { return self._s[2159]! }
    public var PrivacySettings_LastSeen: String { return self._s[2160]! }
    public func DialogList_MultipleTyping(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2161]!, self._r[2161]!, [_0, _1])
    }
    public var Preview_SaveGif: String { return self._s[2165]! }
    public var SettingsSearch_Synonyms_Privacy_TwoStepAuth: String { return self._s[2166]! }
    public var Profile_About: String { return self._s[2167]! }
    public var Channel_About_Placeholder: String { return self._s[2168]! }
    public var Login_InfoTitle: String { return self._s[2169]! }
    public func TwoStepAuth_SetupPendingEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2170]!, self._r[2170]!, [_0])
    }
    public var Watch_Suggestion_CantTalk: String { return self._s[2172]! }
    public var ContactInfo_Title: String { return self._s[2173]! }
    public var Media_ShareThisVideo: String { return self._s[2174]! }
    public var Weekday_ShortFriday: String { return self._s[2175]! }
    public var AccessDenied_Contacts: String { return self._s[2176]! }
    public var Notification_CallIncomingShort: String { return self._s[2177]! }
    public var Group_Setup_TypePublic: String { return self._s[2178]! }
    public var Notifications_MessageNotificationsExceptions: String { return self._s[2179]! }
    public var Notifications_Badge_IncludeChannels: String { return self._s[2180]! }
    public var Notifications_MessageNotificationsPreview: String { return self._s[2183]! }
    public var ConversationProfile_ErrorCreatingConversation: String { return self._s[2184]! }
    public var Group_ErrorAddTooMuchBots: String { return self._s[2185]! }
    public var Privacy_GroupsAndChannels_CustomShareHelp: String { return self._s[2186]! }
    public var Permissions_CellularDataAllowInSettings_v0: String { return self._s[2187]! }
    public var DialogList_Typing: String { return self._s[2188]! }
    public var CallFeedback_IncludeLogs: String { return self._s[2190]! }
    public var Checkout_Phone: String { return self._s[2192]! }
    public var Login_InfoFirstNamePlaceholder: String { return self._s[2195]! }
    public var Privacy_Calls_Integration: String { return self._s[2196]! }
    public var Notifications_PermissionsAllow: String { return self._s[2197]! }
    public var TwoStepAuth_AddHintDescription: String { return self._s[2201]! }
    public var Settings_ChatSettings: String { return self._s[2202]! }
    public func PUSH_MESSAGE_ALBUM(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2203]!, self._r[2203]!, [_1])
    }
    public func Channel_AdminLog_MessageInvitedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2204]!, self._r[2204]!, [_1, _2])
    }
    public var GroupRemoved_DeleteUser: String { return self._s[2206]! }
    public func Channel_AdminLog_PollStopped(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2207]!, self._r[2207]!, [_0])
    }
    public func PUSH_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2208]!, self._r[2208]!, [_1])
    }
    public var Login_ContinueWithLocalization: String { return self._s[2209]! }
    public var Watch_Message_ForwardedFrom: String { return self._s[2210]! }
    public var TwoStepAuth_EnterEmailCode: String { return self._s[2212]! }
    public var Conversation_Unblock: String { return self._s[2213]! }
    public var PrivacySettings_DataSettings: String { return self._s[2214]! }
    public var Notifications_InAppNotificationsVibrate: String { return self._s[2215]! }
    public func Privacy_GroupsAndChannels_InviteToChannelError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2216]!, self._r[2216]!, [_0, _1])
    }
    public var PrivacySettings_Passcode: String { return self._s[2219]! }
    public var Call_Mute: String { return self._s[2220]! }
    public var Passport_Language_dz: String { return self._s[2221]! }
    public var Passport_Language_tk: String { return self._s[2222]! }
    public func Login_EmailCodeSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2223]!, self._r[2223]!, [_0])
    }
    public var Settings_Search: String { return self._s[2224]! }
    public var InfoPlist_NSPhotoLibraryUsageDescription: String { return self._s[2225]! }
    public var Conversation_ContextMenuReply: String { return self._s[2226]! }
    public var WallpaperSearch_ColorBrown: String { return self._s[2227]! }
    public var Tour_Title1: String { return self._s[2228]! }
    public var Conversation_ClearGroupHistory: String { return self._s[2230]! }
    public var WallpaperPreview_Motion: String { return self._s[2231]! }
    public func Checkout_PasswordEntry_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2232]!, self._r[2232]!, [_0])
    }
    public var Call_RateCall: String { return self._s[2233]! }
    public var Channel_AdminLog_BanSendStickersAndGifs: String { return self._s[2234]! }
    public var Passport_PasswordCompleteSetup: String { return self._s[2235]! }
    public var Conversation_InputTextSilentBroadcastPlaceholder: String { return self._s[2236]! }
    public var UserInfo_LastNamePlaceholder: String { return self._s[2238]! }
    public func Login_WillCallYou(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2240]!, self._r[2240]!, [_0])
    }
    public var Compose_Create: String { return self._s[2241]! }
    public var Contacts_InviteToTelegram: String { return self._s[2242]! }
    public var GroupInfo_Notifications: String { return self._s[2243]! }
    public var Message_PinnedLiveLocationMessage: String { return self._s[2245]! }
    public var Month_GenApril: String { return self._s[2246]! }
    public var Appearance_AutoNightTheme: String { return self._s[2247]! }
    public var ChatSettings_AutomaticAudioDownload: String { return self._s[2249]! }
    public var Login_CodeSentSms: String { return self._s[2251]! }
    public func UserInfo_UnblockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2252]!, self._r[2252]!, [_0])
    }
    public var EmptyGroupInfo_Line3: String { return self._s[2253]! }
    public var LogoutOptions_ContactSupportText: String { return self._s[2254]! }
    public var Passport_Language_hr: String { return self._s[2255]! }
    public func Channel_AdminLog_MessageRestrictedNewSetting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2256]!, self._r[2256]!, [_0])
    }
    public var GroupInfo_InviteLink_CopyLink: String { return self._s[2257]! }
    public var Conversation_InputTextBroadcastPlaceholder: String { return self._s[2258]! }
    public var Privacy_SecretChatsTitle: String { return self._s[2259]! }
    public var Notification_SecretChatMessageScreenshotSelf: String { return self._s[2261]! }
    public var GroupInfo_AddUserLeftError: String { return self._s[2262]! }
    public var AutoDownloadSettings_TypePrivateChats: String { return self._s[2263]! }
    public var LogoutOptions_ContactSupportTitle: String { return self._s[2264]! }
    public var Preview_DeleteGif: String { return self._s[2265]! }
    public var GroupInfo_Permissions_Exceptions: String { return self._s[2266]! }
    public var Group_ErrorNotMutualContact: String { return self._s[2267]! }
    public var Notification_MessageLifetime5s: String { return self._s[2268]! }
    public func Watch_LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2269]!, self._r[2269]!, [_0])
    }
    public var Passport_Address_AddBankStatement: String { return self._s[2271]! }
    public var Notification_CallIncoming: String { return self._s[2272]! }
    public var Compose_NewGroupTitle: String { return self._s[2273]! }
    public var TwoStepAuth_RecoveryCodeHelp: String { return self._s[2275]! }
    public var Passport_Address_Postcode: String { return self._s[2277]! }
    public func LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2278]!, self._r[2278]!, [_0])
    }
    public var Checkout_NewCard_SaveInfoHelp: String { return self._s[2279]! }
    public var WallpaperColors_Title: String { return self._s[2280]! }
    public var SocksProxySetup_ShareQRCodeInfo: String { return self._s[2281]! }
    public var GroupPermission_Duration: String { return self._s[2282]! }
    public func Cache_Clear(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2283]!, self._r[2283]!, [_0])
    }
    public var Bot_GroupStatusDoesNotReadHistory: String { return self._s[2284]! }
    public var Username_Placeholder: String { return self._s[2285]! }
    public var CallFeedback_WhatWentWrong: String { return self._s[2286]! }
    public var Passport_FieldAddressUploadHelp: String { return self._s[2287]! }
    public var Permissions_NotificationsAllowInSettings_v0: String { return self._s[2288]! }
    public var Passport_PasswordDescription: String { return self._s[2290]! }
    public var Channel_MessagePhotoUpdated: String { return self._s[2291]! }
    public var MediaPicker_TapToUngroupDescription: String { return self._s[2292]! }
    public var SettingsSearch_Synonyms_Notifications_BadgeCountUnreadMessages: String { return self._s[2293]! }
    public var AttachmentMenu_PhotoOrVideo: String { return self._s[2294]! }
    public var Conversation_ContextMenuMore: String { return self._s[2295]! }
    public var Privacy_PaymentsClearInfo: String { return self._s[2296]! }
    public var CallSettings_TabIcon: String { return self._s[2297]! }
    public var KeyCommand_Find: String { return self._s[2298]! }
    public var Message_PinnedGame: String { return self._s[2299]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOff: String { return self._s[2301]! }
    public var Login_CallRequestState2: String { return self._s[2303]! }
    public var CheckoutInfo_ReceiverInfoNamePlaceholder: String { return self._s[2305]! }
    public func Checkout_PayPrice(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2307]!, self._r[2307]!, [_0])
    }
    public var WallpaperPreview_Blurred: String { return self._s[2308]! }
    public var Conversation_InstantPagePreview: String { return self._s[2309]! }
    public func DialogList_SingleUploadingVideoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2310]!, self._r[2310]!, [_0])
    }
    public var SecretTimer_VideoDescription: String { return self._s[2313]! }
    public var WallpaperSearch_ColorRed: String { return self._s[2314]! }
    public var GroupPermission_NoPinMessages: String { return self._s[2315]! }
    public var Passport_Language_es: String { return self._s[2316]! }
    public var Permissions_ContactsAllow_v0: String { return self._s[2318]! }
    public var Conversation_EditingMessageMediaEditCurrentVideo: String { return self._s[2319]! }
    public func PUSH_CHAT_MESSAGE_CONTACT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2320]!, self._r[2320]!, [_1, _2])
    }
    public var Privacy_Forwards_CustomHelp: String { return self._s[2321]! }
    public var WebPreview_GettingLinkInfo: String { return self._s[2322]! }
    public var Watch_UserInfo_Unmute: String { return self._s[2323]! }
    public var GroupInfo_ChannelListNamePlaceholder: String { return self._s[2324]! }
    public var AccessDenied_CameraRestricted: String { return self._s[2326]! }
    public func Conversation_Kilobytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2327]!, self._r[2327]!, ["\(_0)"])
    }
    public var ChatList_ReadAll: String { return self._s[2329]! }
    public var Settings_CopyUsername: String { return self._s[2330]! }
    public var Contacts_SearchLabel: String { return self._s[2331]! }
    public var Map_OpenInYandexNavigator: String { return self._s[2333]! }
    public var PasscodeSettings_EncryptData: String { return self._s[2334]! }
    public var WallpaperSearch_ColorPrefix: String { return self._s[2335]! }
    public var Notifications_GroupNotificationsPreview: String { return self._s[2336]! }
    public var DialogList_AdNoticeAlert: String { return self._s[2337]! }
    public var CheckoutInfo_ShippingInfoAddress1: String { return self._s[2339]! }
    public var CheckoutInfo_ShippingInfoAddress2: String { return self._s[2340]! }
    public var Localization_LanguageCustom: String { return self._s[2341]! }
    public var Passport_Identity_TypeDriversLicenseUploadScan: String { return self._s[2342]! }
    public var CallFeedback_Title: String { return self._s[2343]! }
    public var Passport_Address_OneOfTypePassportRegistration: String { return self._s[2346]! }
    public var Conversation_InfoGroup: String { return self._s[2347]! }
    public var Compose_NewMessage: String { return self._s[2348]! }
    public var FastTwoStepSetup_HintPlaceholder: String { return self._s[2349]! }
    public var ChatSettings_AutoDownloadVideoMessages: String { return self._s[2350]! }
    public func Passport_Scans_ScanIndex(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2351]!, self._r[2351]!, [_0])
    }
    public var Channel_AdminLog_CanDeleteMessages: String { return self._s[2352]! }
    public var Login_CancelSignUpConfirmation: String { return self._s[2353]! }
    public var ChangePhoneNumberCode_Help: String { return self._s[2354]! }
    public var PrivacySettings_DeleteAccountHelp: String { return self._s[2355]! }
    public var Channel_BlackList_Title: String { return self._s[2356]! }
    public var UserInfo_PhoneCall: String { return self._s[2357]! }
    public var Passport_Address_OneOfTypeBankStatement: String { return self._s[2359]! }
    public var State_connecting: String { return self._s[2360]! }
    public func DialogList_SingleRecordingAudioSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2361]!, self._r[2361]!, [_0])
    }
    public var Notifications_GroupNotifications: String { return self._s[2362]! }
    public var Passport_Identity_EditPassport: String { return self._s[2363]! }
    public var EnterPasscode_RepeatNewPasscode: String { return self._s[2365]! }
    public var Localization_EnglishLanguageName: String { return self._s[2366]! }
    public var Share_AuthDescription: String { return self._s[2367]! }
    public var SettingsSearch_Synonyms_Notifications_ChannelNotificationsAlert: String { return self._s[2368]! }
    public var Passport_Identity_Surname: String { return self._s[2369]! }
    public var Compose_TokenListPlaceholder: String { return self._s[2370]! }
    public var Passport_Identity_OneOfTypePassport: String { return self._s[2371]! }
    public var Settings_AboutEmpty: String { return self._s[2372]! }
    public var Conversation_Unmute: String { return self._s[2373]! }
    public func PUSH_CONTACT_JOINED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2375]!, self._r[2375]!, [_1])
    }
    public var Login_CodeSentCall: String { return self._s[2376]! }
    public var ContactInfo_PhoneLabelHomeFax: String { return self._s[2378]! }
    public var ChatSettings_Appearance: String { return self._s[2379]! }
    public var Appearance_PickAccentColor: String { return self._s[2380]! }
    public func PUSH_CHAT_MESSAGE_NOTEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2381]!, self._r[2381]!, [_1, _2])
    }
    public func PUSH_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2382]!, self._r[2382]!, [_1])
    }
    public var Notification_CallMissed: String { return self._s[2383]! }
    public var SettingsSearch_Synonyms_Appearance_ChatBackground_Custom: String { return self._s[2384]! }
    public var Channel_AdminLogFilter_EventsInfo: String { return self._s[2385]! }
    public var ChatAdmins_AdminLabel: String { return self._s[2387]! }
    public var KeyCommand_JumpToNextChat: String { return self._s[2388]! }
    public var Conversation_StopPollConfirmationTitle: String { return self._s[2390]! }
    public var ChangePhoneNumberCode_CodePlaceholder: String { return self._s[2391]! }
    public var Month_GenJune: String { return self._s[2392]! }
    public var Watch_Location_Current: String { return self._s[2393]! }
    public var Conversation_TitleMute: String { return self._s[2394]! }
    public func PUSH_CHANNEL_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2395]!, self._r[2395]!, [_1])
    }
    public var GroupInfo_DeleteAndExit: String { return self._s[2396]! }
    public func Conversation_Moderate_DeleteAllMessages(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2397]!, self._r[2397]!, [_0])
    }
    public var Call_ReportPlaceholder: String { return self._s[2398]! }
    public var MaskStickerSettings_Info: String { return self._s[2399]! }
    public func GroupInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2400]!, self._r[2400]!, [_0])
    }
    public var Checkout_NewCard_PostcodeTitle: String { return self._s[2401]! }
    public var Passport_Address_RegionPlaceholder: String { return self._s[2403]! }
    public var Contacts_ShareTelegram: String { return self._s[2404]! }
    public var EnterPasscode_EnterNewPasscodeNew: String { return self._s[2405]! }
    public var Channel_ErrorAccessDenied: String { return self._s[2406]! }
    public var Stickers_GroupChooseStickerPack: String { return self._s[2408]! }
    public var Call_ConnectionErrorTitle: String { return self._s[2409]! }
    public var UserInfo_NotificationsEnable: String { return self._s[2410]! }
    public var Tour_Text4: String { return self._s[2413]! }
    public var WallpaperSearch_Recent: String { return self._s[2414]! }
    public var Profile_MessageLifetime2s: String { return self._s[2416]! }
    public var Notification_MessageLifetime2s: String { return self._s[2417]! }
    public func Time_PreciseDate_m10(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2418]!, self._r[2418]!, [_1, _2, _3])
    }
    public var Cache_ClearCache: String { return self._s[2419]! }
    public var AutoNightTheme_UpdateLocation: String { return self._s[2420]! }
    public var Permissions_NotificationsUnreachableText_v0: String { return self._s[2421]! }
    public func Channel_AdminLog_MessageChangedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2425]!, self._r[2425]!, [_0])
    }
    public var Channel_AdminLog_EmptyFilterTitle: String { return self._s[2427]! }
    public var SocksProxySetup_TypeSocks: String { return self._s[2428]! }
    public var ChatList_UnarchiveAction: String { return self._s[2429]! }
    public var AutoNightTheme_Title: String { return self._s[2430]! }
    public var InstantPage_FeedbackButton: String { return self._s[2431]! }
    public var Passport_FieldAddress: String { return self._s[2432]! }
    public var Month_ShortMarch: String { return self._s[2433]! }
    public func PUSH_MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2434]!, self._r[2434]!, [_1, _2])
    }
    public var SocksProxySetup_UsernamePlaceholder: String { return self._s[2435]! }
    public var Conversation_ShareInlineBotLocationConfirmation: String { return self._s[2436]! }
    public var Passport_FloodError: String { return self._s[2437]! }
    public var SecretGif_Title: String { return self._s[2438]! }
    public var NotificationSettings_ShowNotificationsAllAccountsInfoOn: String { return self._s[2439]! }
    public var Passport_Language_th: String { return self._s[2441]! }
    public var Passport_Address_Address: String { return self._s[2442]! }
    public var Login_InvalidLastNameError: String { return self._s[2443]! }
    public var Notifications_InAppNotificationsPreview: String { return self._s[2444]! }
    public var Notifications_PermissionsUnreachableTitle: String { return self._s[2445]! }
    public var SettingsSearch_FAQ: String { return self._s[2446]! }
    public var ShareMenu_Send: String { return self._s[2447]! }
    public var WallpaperSearch_ColorYellow: String { return self._s[2449]! }
    public var Month_GenNovember: String { return self._s[2451]! }
    public var SettingsSearch_Synonyms_Appearance_LargeEmoji: String { return self._s[2453]! }
    public var Checkout_Email: String { return self._s[2454]! }
    public var NotificationsSound_Tritone: String { return self._s[2455]! }
    public var StickerPacksSettings_ManagingHelp: String { return self._s[2457]! }
    public func PUSH_PINNED_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2460]!, self._r[2460]!, [_1])
    }
    public var ChangePhoneNumberNumber_Help: String { return self._s[2461]! }
    public func Checkout_LiabilityAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2462]!, self._r[2462]!, [_1, _1, _1, _2])
    }
    public var DialogList_You: String { return self._s[2463]! }
    public var MediaPicker_Send: String { return self._s[2466]! }
    public var SettingsSearch_Synonyms_Stickers_Title: String { return self._s[2467]! }
    public var Call_AudioRouteSpeaker: String { return self._s[2468]! }
    public var Watch_UserInfo_Title: String { return self._s[2469]! }
    public var Appearance_AccentColor: String { return self._s[2470]! }
    public func Login_EmailPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2471]!, self._r[2471]!, [_0])
    }
    public var Permissions_ContactsAllowInSettings_v0: String { return self._s[2472]! }
    public func PUSH_CHANNEL_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2473]!, self._r[2473]!, [_1, _2])
    }
    public var Conversation_ClousStorageInfo_Description2: String { return self._s[2474]! }
    public var WebSearch_RecentClearConfirmation: String { return self._s[2475]! }
    public var Notification_CallOutgoing: String { return self._s[2476]! }
    public var PrivacySettings_PasscodeAndFaceId: String { return self._s[2477]! }
    public var Call_RecordingDisabledMessage: String { return self._s[2478]! }
    public var Conversation_PressVolumeButtonForSound: String { return self._s[2479]! }
    public var PrivacyLastSeenSettings_CustomHelp: String { return self._s[2480]! }
    public var Channel_EditAdmin_PermissionAddAdmins: String { return self._s[2481]! }
    public var Date_DialogDateFormat: String { return self._s[2482]! }
    public var WallpaperColors_SetCustomColor: String { return self._s[2483]! }
    public var Notifications_InAppNotifications: String { return self._s[2484]! }
    public func Channel_Management_RemovedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2485]!, self._r[2485]!, [_0])
    }
    public func Settings_ApplyProxyAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2486]!, self._r[2486]!, [_1, _2])
    }
    public var NewContact_Title: String { return self._s[2487]! }
    public func AutoDownloadSettings_UpToForAll(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2488]!, self._r[2488]!, [_0])
    }
    public var Conversation_ViewContactDetails: String { return self._s[2489]! }
    public func PUSH_CHANNEL_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2491]!, self._r[2491]!, [_1])
    }
    public var Checkout_NewCard_CardholderNameTitle: String { return self._s[2492]! }
    public var Passport_Identity_ExpiryDateNone: String { return self._s[2493]! }
    public var PrivacySettings_Title: String { return self._s[2494]! }
    public var Conversation_SilentBroadcastTooltipOff: String { return self._s[2497]! }
    public var GroupRemoved_UsersSectionTitle: String { return self._s[2498]! }
    public var Contacts_PhoneNumber: String { return self._s[2499]! }
    public var Map_ShowPlaces: String { return self._s[2501]! }
    public var ChatAdmins_Title: String { return self._s[2502]! }
    public var InstantPage_Reference: String { return self._s[2504]! }
    public func PUSH_CHAT_MESSAGE_FWD(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2505]!, self._r[2505]!, [_1, _2])
    }
    public var Camera_FlashOff: String { return self._s[2506]! }
    public var Watch_UserInfo_Block: String { return self._s[2507]! }
    public var ChatSettings_Stickers: String { return self._s[2508]! }
    public var ChatSettings_DownloadInBackground: String { return self._s[2509]! }
    public func UserInfo_BlockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2510]!, self._r[2510]!, [_0])
    }
    public var Settings_ViewPhoto: String { return self._s[2511]! }
    public var Login_CheckOtherSessionMessages: String { return self._s[2512]! }
    public var AutoDownloadSettings_Cellular: String { return self._s[2513]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsExceptions: String { return self._s[2514]! }
    public func Target_InviteToGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2516]!, self._r[2516]!, [_0])
    }
    public var Privacy_DeleteDrafts: String { return self._s[2517]! }
    public var Wallpaper_SetCustomBackgroundInfo: String { return self._s[2518]! }
    public func LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2519]!, self._r[2519]!, [_0])
    }
    public var DialogList_SavedMessagesHelp: String { return self._s[2520]! }
    public var DialogList_SavedMessages: String { return self._s[2521]! }
    public var GroupInfo_UpgradeButton: String { return self._s[2522]! }
    public var DialogList_Pin: String { return self._s[2524]! }
    public func ForwardedAuthors2(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2525]!, self._r[2525]!, [_0, _1])
    }
    public func Login_PhoneGenericEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2526]!, self._r[2526]!, [_0])
    }
    public var Notification_Exceptions_AlwaysOn: String { return self._s[2527]! }
    public var UserInfo_NotificationsDisable: String { return self._s[2528]! }
    public var Paint_Outlined: String { return self._s[2529]! }
    public var Activity_PlayingGame: String { return self._s[2530]! }
    public var SearchImages_NoImagesFound: String { return self._s[2531]! }
    public var SocksProxySetup_ProxyType: String { return self._s[2532]! }
    public var AppleWatch_ReplyPresetsHelp: String { return self._s[2534]! }
    public var Conversation_ContextMenuCancelSending: String { return self._s[2535]! }
    public var Settings_AppLanguage: String { return self._s[2536]! }
    public var TwoStepAuth_ResetAccountHelp: String { return self._s[2537]! }
    public var Common_ChoosePhoto: String { return self._s[2538]! }
    public var CallFeedback_ReasonEcho: String { return self._s[2539]! }
    public func PUSH_PINNED_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2540]!, self._r[2540]!, [_1])
    }
    public var Privacy_Calls_AlwaysAllow: String { return self._s[2541]! }
    public var Activity_UploadingVideo: String { return self._s[2542]! }
    public var ChannelInfo_DeleteChannelConfirmation: String { return self._s[2543]! }
    public var NetworkUsageSettings_Wifi: String { return self._s[2544]! }
    public var Channel_BanUser_PermissionReadMessages: String { return self._s[2545]! }
    public var Checkout_PayWithTouchId: String { return self._s[2546]! }
    public var Wallpaper_ResetWallpapersConfirmation: String { return self._s[2547]! }
    public func PUSH_LOCKED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2549]!, self._r[2549]!, [_1])
    }
    public var Notifications_ExceptionsNone: String { return self._s[2550]! }
    public func Message_ForwardedMessageShort(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2551]!, self._r[2551]!, [_0])
    }
    public func PUSH_PINNED_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2552]!, self._r[2552]!, [_1])
    }
    public var AuthSessions_IncompleteAttempts: String { return self._s[2554]! }
    public var Passport_Address_Region: String { return self._s[2557]! }
    public var ChatList_DeleteChat: String { return self._s[2558]! }
    public var LogoutOptions_ClearCacheTitle: String { return self._s[2559]! }
    public var PhotoEditor_TiltShift: String { return self._s[2560]! }
    public var Settings_FAQ_URL: String { return self._s[2561]! }
    public var Passport_Language_sl: String { return self._s[2562]! }
    public var Settings_PrivacySettings: String { return self._s[2564]! }
    public var SharedMedia_TitleLink: String { return self._s[2565]! }
    public var Passport_Identity_TypePassportUploadScan: String { return self._s[2566]! }
    public var Settings_SetProfilePhoto: String { return self._s[2567]! }
    public var Channel_About_Help: String { return self._s[2568]! }
    public var Contacts_PermissionsEnable: String { return self._s[2569]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsAlert: String { return self._s[2570]! }
    public var AttachmentMenu_SendAsFiles: String { return self._s[2571]! }
    public var CallFeedback_ReasonInterruption: String { return self._s[2573]! }
    public var Passport_Address_AddTemporaryRegistration: String { return self._s[2574]! }
    public var AutoDownloadSettings_AutodownloadVideos: String { return self._s[2575]! }
    public var ChatSettings_AutoDownloadSettings_Delimeter: String { return self._s[2576]! }
    public var PrivacySettings_DeleteAccountTitle: String { return self._s[2577]! }
    public var AccessDenied_VideoMessageCamera: String { return self._s[2579]! }
    public var Map_OpenInYandexMaps: String { return self._s[2581]! }
    public var PhotoEditor_SaturationTool: String { return self._s[2582]! }
    public func PUSH_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2583]!, self._r[2583]!, [_1, _2])
    }
    public var Notification_Exceptions_NewException_NotificationHeader: String { return self._s[2584]! }
    public var Appearance_TextSize: String { return self._s[2585]! }
    public func LOCAL_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2586]!, self._r[2586]!, [_1, "\(_2)"])
    }
    public var Channel_Username_InvalidTooShort: String { return self._s[2588]! }
    public func PUSH_CHAT_MESSAGE_GAME(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2589]!, self._r[2589]!, [_1, _2, _3])
    }
    public var Passport_PassportInformation: String { return self._s[2592]! }
    public var WatchRemote_AlertTitle: String { return self._s[2593]! }
    public var Privacy_GroupsAndChannels_NeverAllow: String { return self._s[2594]! }
    public var ConvertToSupergroup_HelpText: String { return self._s[2596]! }
    public func Time_MonthOfYear_m7(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2597]!, self._r[2597]!, [_0])
    }
    public func PUSH_PHONE_CALL_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2598]!, self._r[2598]!, [_1])
    }
    public var Privacy_GroupsAndChannels_CustomHelp: String { return self._s[2599]! }
    public var TwoStepAuth_RecoveryCodeInvalid: String { return self._s[2601]! }
    public var AccessDenied_CameraDisabled: String { return self._s[2602]! }
    public func Channel_Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2603]!, self._r[2603]!, [_0])
    }
    public var PhotoEditor_ContrastTool: String { return self._s[2606]! }
    public func PUSH_PINNED_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2607]!, self._r[2607]!, [_1])
    }
    public var DialogList_Draft: String { return self._s[2608]! }
    public var Privacy_TopPeersDelete: String { return self._s[2610]! }
    public var LoginPassword_PasswordPlaceholder: String { return self._s[2611]! }
    public var Passport_Identity_TypeIdentityCardUploadScan: String { return self._s[2612]! }
    public var WebSearch_RecentSectionClear: String { return self._s[2613]! }
    public var Watch_ChatList_NoConversationsTitle: String { return self._s[2615]! }
    public var Common_Done: String { return self._s[2617]! }
    public var AuthSessions_EmptyText: String { return self._s[2618]! }
    public var Conversation_ShareBotContactConfirmation: String { return self._s[2619]! }
    public var Tour_Title5: String { return self._s[2620]! }
    public func Map_DirectionsDriveEta(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2621]!, self._r[2621]!, [_0])
    }
    public var ApplyLanguage_UnsufficientDataTitle: String { return self._s[2622]! }
    public var Conversation_LinkDialogSave: String { return self._s[2623]! }
    public var GroupInfo_ActionRestrict: String { return self._s[2624]! }
    public var Checkout_Title: String { return self._s[2625]! }
    public var Channel_AdminLog_CanChangeInfo: String { return self._s[2628]! }
    public var Notification_RenamedGroup: String { return self._s[2629]! }
    public var Checkout_PayWithFaceId: String { return self._s[2630]! }
    public var Channel_BanList_BlockedTitle: String { return self._s[2631]! }
    public var SettingsSearch_Synonyms_Notifications_InAppNotificationsSound: String { return self._s[2633]! }
    public var Checkout_WebConfirmation_Title: String { return self._s[2634]! }
    public var Notifications_MessageNotificationsAlert: String { return self._s[2635]! }
    public var Profile_AddToExisting: String { return self._s[2637]! }
    public func Profile_CreateEncryptedChatOutdatedError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2638]!, self._r[2638]!, [_0, _1])
    }
    public var Cache_Files: String { return self._s[2640]! }
    public var Permissions_PrivacyPolicy: String { return self._s[2641]! }
    public var SocksProxySetup_ConnectAndSave: String { return self._s[2642]! }
    public var UserInfo_NotificationsDefaultDisabled: String { return self._s[2643]! }
    public var AutoDownloadSettings_TypeContacts: String { return self._s[2645]! }
    public var Calls_NoCallsPlaceholder: String { return self._s[2647]! }
    public var Channel_Username_RevokeExistingUsernamesInfo: String { return self._s[2648]! }
    public var Notifications_ExceptionsGroupPlaceholder: String { return self._s[2650]! }
    public func PUSH_CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2651]!, self._r[2651]!, [_1, _2, _3])
    }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsSound: String { return self._s[2652]! }
    public var Passport_FieldAddressHelp: String { return self._s[2653]! }
    public var Privacy_GroupsAndChannels_InviteToChannelMultipleError: String { return self._s[2654]! }
    public func Login_TermsOfService_ProceedBot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2655]!, self._r[2655]!, [_0])
    }
    public var Channel_AdminLog_EmptyTitle: String { return self._s[2656]! }
    public var Privacy_Calls_NeverAllow_Title: String { return self._s[2658]! }
    public var Login_UnknownError: String { return self._s[2659]! }
    public var Group_UpgradeNoticeText2: String { return self._s[2661]! }
    public var Watch_Compose_AddContact: String { return self._s[2662]! }
    public var Web_Error: String { return self._s[2663]! }
    public var Gif_Search: String { return self._s[2664]! }
    public var Profile_MessageLifetime1h: String { return self._s[2665]! }
    public var CheckoutInfo_ReceiverInfoEmailPlaceholder: String { return self._s[2666]! }
    public var Channel_Username_CheckingUsername: String { return self._s[2667]! }
    public var CallFeedback_ReasonSilentRemote: String { return self._s[2668]! }
    public var AutoDownloadSettings_TypeChannels: String { return self._s[2669]! }
    public var Channel_AboutItem: String { return self._s[2670]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Placeholder: String { return self._s[2672]! }
    public var GroupInfo_SharedMedia: String { return self._s[2673]! }
    public func Channel_AdminLog_MessagePromotedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2674]!, self._r[2674]!, [_1])
    }
    public var Call_PhoneCallInProgressMessage: String { return self._s[2675]! }
    public func PUSH_CHANNEL_ALBUM(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2676]!, self._r[2676]!, [_1])
    }
    public var GroupInfo_InviteLink_RevokeAlert_Text: String { return self._s[2677]! }
    public var Conversation_SearchByName_Placeholder: String { return self._s[2678]! }
    public var CreatePoll_AddOption: String { return self._s[2679]! }
    public var GroupInfo_Permissions_SearchPlaceholder: String { return self._s[2680]! }
    public var Group_UpgradeNoticeHeader: String { return self._s[2681]! }
    public var Channel_Management_AddModerator: String { return self._s[2682]! }
    public var AutoDownloadSettings_MaxFileSize: String { return self._s[2683]! }
    public var StickerPacksSettings_ShowStickersButton: String { return self._s[2684]! }
    public var NotificationsSound_Hello: String { return self._s[2685]! }
    public var SocksProxySetup_SavedProxies: String { return self._s[2686]! }
    public var Channel_Stickers_Placeholder: String { return self._s[2688]! }
    public func Login_EmailCodeBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2689]!, self._r[2689]!, [_0])
    }
    public var PrivacyPolicy_DeclineDeclineAndDelete: String { return self._s[2690]! }
    public var Channel_Management_AddModeratorHelp: String { return self._s[2691]! }
    public var ContactInfo_BirthdayLabel: String { return self._s[2692]! }
    public var ChangePhoneNumberCode_RequestingACall: String { return self._s[2693]! }
    public var AutoDownloadSettings_Channels: String { return self._s[2694]! }
    public var Passport_Language_mn: String { return self._s[2695]! }
    public var Notifications_ResetAllNotificationsHelp: String { return self._s[2698]! }
    public var Passport_Language_ja: String { return self._s[2700]! }
    public var Settings_About_Title: String { return self._s[2701]! }
    public var Settings_NotificationsAndSounds: String { return self._s[2702]! }
    public var ChannelInfo_DeleteGroup: String { return self._s[2703]! }
    public var Settings_BlockedUsers: String { return self._s[2704]! }
    public func Time_MonthOfYear_m4(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2705]!, self._r[2705]!, [_0])
    }
    public var AutoDownloadSettings_PreloadVideo: String { return self._s[2706]! }
    public var Passport_Address_AddResidentialAddress: String { return self._s[2707]! }
    public var Channel_Username_Title: String { return self._s[2708]! }
    public func Notification_RemovedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2709]!, self._r[2709]!, [_0])
    }
    public var AttachmentMenu_File: String { return self._s[2711]! }
    public var AppleWatch_Title: String { return self._s[2712]! }
    public var Activity_RecordingVideoMessage: String { return self._s[2713]! }
    public var Weekday_Saturday: String { return self._s[2714]! }
    public var WallpaperPreview_SwipeColorsTopText: String { return self._s[2715]! }
    public var Profile_CreateEncryptedChatError: String { return self._s[2716]! }
    public var Common_Next: String { return self._s[2718]! }
    public var Channel_Stickers_YourStickers: String { return self._s[2720]! }
    public var Call_AudioRouteHeadphones: String { return self._s[2721]! }
    public var TwoStepAuth_EnterPasswordForgot: String { return self._s[2723]! }
    public var Watch_Contacts_NoResults: String { return self._s[2725]! }
    public var PhotoEditor_TintTool: String { return self._s[2728]! }
    public var LoginPassword_ResetAccount: String { return self._s[2730]! }
    public var Settings_SavedMessages: String { return self._s[2731]! }
    public var SettingsSearch_Synonyms_Appearance_Animations: String { return self._s[2732]! }
    public var Bot_GenericSupportStatus: String { return self._s[2733]! }
    public var StickerPack_Add: String { return self._s[2734]! }
    public var Checkout_TotalAmount: String { return self._s[2735]! }
    public var Your_cards_number_is_invalid: String { return self._s[2736]! }
    public var SettingsSearch_Synonyms_Appearance_AutoNightTheme: String { return self._s[2737]! }
    public func ChangePhoneNumberCode_CallTimer(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2738]!, self._r[2738]!, [_0])
    }
    public func GroupPermission_AddedInfo(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2739]!, self._r[2739]!, [_1, _2])
    }
    public var ChatSettings_ConnectionType_UseSocks5: String { return self._s[2740]! }
    public func PUSH_CHAT_PHOTO_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2742]!, self._r[2742]!, [_1, _2])
    }
    public func Conversation_RestrictedTextTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2743]!, self._r[2743]!, [_0])
    }
    public var GroupInfo_InviteLink_ShareLink: String { return self._s[2744]! }
    public var StickerPack_Share: String { return self._s[2745]! }
    public var Passport_DeleteAddress: String { return self._s[2746]! }
    public var Settings_Passport: String { return self._s[2747]! }
    public var SharedMedia_EmptyFilesText: String { return self._s[2748]! }
    public var Conversation_DeleteMessagesForMe: String { return self._s[2749]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1hour: String { return self._s[2750]! }
    public var Contacts_PermissionsText: String { return self._s[2751]! }
    public var Group_Setup_HistoryVisible: String { return self._s[2752]! }
    public var Passport_Address_AddRentalAgreement: String { return self._s[2754]! }
    public var SocksProxySetup_Title: String { return self._s[2755]! }
    public var Notification_Mute1h: String { return self._s[2756]! }
    public func Passport_Email_CodeHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2757]!, self._r[2757]!, [_0])
    }
    public var NotificationSettings_ShowNotificationsAllAccountsInfoOff: String { return self._s[2758]! }
    public func PUSH_PINNED_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2759]!, self._r[2759]!, [_1])
    }
    public var FastTwoStepSetup_PasswordSection: String { return self._s[2760]! }
    public var NetworkUsageSettings_ResetStatsConfirmation: String { return self._s[2763]! }
    public var InfoPlist_NSFaceIDUsageDescription: String { return self._s[2765]! }
    public var DialogList_NoMessagesText: String { return self._s[2766]! }
    public var Privacy_ContactsResetConfirmation: String { return self._s[2767]! }
    public var Privacy_Calls_P2PHelp: String { return self._s[2768]! }
    public var Your_cards_expiration_year_is_invalid: String { return self._s[2770]! }
    public var Common_TakePhotoOrVideo: String { return self._s[2771]! }
    public var Call_StatusBusy: String { return self._s[2772]! }
    public var Conversation_PinnedMessage: String { return self._s[2773]! }
    public var AutoDownloadSettings_VoiceMessagesTitle: String { return self._s[2774]! }
    public var TwoStepAuth_SetupPasswordConfirmFailed: String { return self._s[2775]! }
    public var Undo_ChatCleared: String { return self._s[2776]! }
    public var AppleWatch_ReplyPresets: String { return self._s[2777]! }
    public var Passport_DiscardMessageDescription: String { return self._s[2779]! }
    public var Login_NetworkError: String { return self._s[2780]! }
    public func Notification_PinnedRoundMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2781]!, self._r[2781]!, [_0])
    }
    public func Channel_AdminLog_MessageRemovedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2782]!, self._r[2782]!, [_0])
    }
    public var SocksProxySetup_PasswordPlaceholder: String { return self._s[2783]! }
    public var Login_ResetAccountProtected_LimitExceeded: String { return self._s[2785]! }
    public func Watch_LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2787]!, self._r[2787]!, [_0])
    }
    public var Call_ConnectionErrorMessage: String { return self._s[2788]! }
    public var SettingsSearch_Synonyms_Notifications_MessageNotificationsSound: String { return self._s[2789]! }
    public var Compose_GroupTokenListPlaceholder: String { return self._s[2791]! }
    public var ConversationMedia_Title: String { return self._s[2792]! }
    public var EncryptionKey_Title: String { return self._s[2794]! }
    public var TwoStepAuth_EnterPasswordTitle: String { return self._s[2795]! }
    public var Notification_Exceptions_AddException: String { return self._s[2796]! }
    public var Profile_MessageLifetime1m: String { return self._s[2797]! }
    public func Channel_AdminLog_MessageUnkickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2798]!, self._r[2798]!, [_1])
    }
    public var Month_GenMay: String { return self._s[2799]! }
    public func LiveLocationUpdated_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2800]!, self._r[2800]!, [_0])
    }
    public var ChannelMembers_WhoCanAddMembersAllHelp: String { return self._s[2801]! }
    public var AutoDownloadSettings_ResetSettings: String { return self._s[2802]! }
    public var Conversation_EmptyPlaceholder: String { return self._s[2804]! }
    public var Passport_Address_AddPassportRegistration: String { return self._s[2805]! }
    public var Notifications_ChannelNotificationsAlert: String { return self._s[2806]! }
    public var ChatSettings_AutoDownloadUsingCellular: String { return self._s[2807]! }
    public var Camera_TapAndHoldForVideo: String { return self._s[2808]! }
    public var Channel_JoinChannel: String { return self._s[2810]! }
    public var Appearance_Animations: String { return self._s[2813]! }
    public func Notification_MessageLifetimeChanged(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2814]!, self._r[2814]!, [_1, _2])
    }
    public var Stickers_GroupStickers: String { return self._s[2816]! }
    public var ConvertToSupergroup_HelpTitle: String { return self._s[2818]! }
    public var Passport_Address_Street: String { return self._s[2819]! }
    public var Conversation_AddContact: String { return self._s[2820]! }
    public var Login_PhonePlaceholder: String { return self._s[2821]! }
    public var Channel_Members_InviteLink: String { return self._s[2823]! }
    public var Bot_Stop: String { return self._s[2824]! }
    public var SettingsSearch_Synonyms_Proxy_UseForCalls: String { return self._s[2826]! }
    public var Notification_PassportValueAddress: String { return self._s[2827]! }
    public var Month_ShortJuly: String { return self._s[2828]! }
    public var Passport_Address_TypeTemporaryRegistrationUploadScan: String { return self._s[2829]! }
    public var Channel_AdminLog_BanSendMedia: String { return self._s[2830]! }
    public var Passport_Identity_ReverseSide: String { return self._s[2831]! }
    public var Watch_Stickers_Recents: String { return self._s[2834]! }
    public var PrivacyLastSeenSettings_EmpryUsersPlaceholder: String { return self._s[2836]! }
    public var Map_SendThisLocation: String { return self._s[2837]! }
    public func Time_MonthOfYear_m1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2838]!, self._r[2838]!, [_0])
    }
    public func InviteText_SingleContact(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2839]!, self._r[2839]!, [_0])
    }
    public var ConvertToSupergroup_Note: String { return self._s[2840]! }
    public func FileSize_MB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2841]!, self._r[2841]!, [_0])
    }
    public var NetworkUsageSettings_GeneralDataSection: String { return self._s[2842]! }
    public func Compatibility_SecretMediaVersionTooLow(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2843]!, self._r[2843]!, [_0, _1])
    }
    public var Login_CallRequestState3: String { return self._s[2845]! }
    public var Wallpaper_SearchShort: String { return self._s[2846]! }
    public var SettingsSearch_Synonyms_Appearance_ColorTheme: String { return self._s[2848]! }
    public var PasscodeSettings_UnlockWithFaceId: String { return self._s[2849]! }
    public func PUSH_CHAT_MESSAGE_GEOLIVE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2850]!, self._r[2850]!, [_1, _2])
    }
    public var Channel_AdminLogFilter_Title: String { return self._s[2851]! }
    public var Notifications_GroupNotificationsExceptions: String { return self._s[2855]! }
    public func FileSize_B(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2856]!, self._r[2856]!, [_0])
    }
    public var Passport_CorrectErrors: String { return self._s[2857]! }
    public func Channel_MessageTitleUpdated(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2858]!, self._r[2858]!, [_0])
    }
    public var Map_SendMyCurrentLocation: String { return self._s[2859]! }
    public func PUSH_PINNED_CONTACT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2860]!, self._r[2860]!, [_1, _2])
    }
    public var SharedMedia_SearchNoResults: String { return self._s[2861]! }
    public var Permissions_NotificationsText_v0: String { return self._s[2862]! }
    public var LoginPassword_FloodError: String { return self._s[2863]! }
    public var Group_Setup_HistoryHiddenHelp: String { return self._s[2865]! }
    public func TwoStepAuth_PendingEmailHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2866]!, self._r[2866]!, [_0])
    }
    public var Passport_Language_bn: String { return self._s[2867]! }
    public func DialogList_SingleUploadingPhotoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2868]!, self._r[2868]!, [_0])
    }
    public func Notification_PinnedAudioMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2869]!, self._r[2869]!, [_0])
    }
    public func Channel_AdminLog_MessageChangedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2870]!, self._r[2870]!, [_0])
    }
    public var GroupInfo_InvitationLinkGroupFull: String { return self._s[2873]! }
    public var Group_EditAdmin_PermissionChangeInfo: String { return self._s[2875]! }
    public var Contacts_PermissionsAllow: String { return self._s[2876]! }
    public var ReportPeer_ReasonCopyright: String { return self._s[2877]! }
    public var Channel_EditAdmin_PermissinAddAdminOn: String { return self._s[2878]! }
    public var WallpaperPreview_Pattern: String { return self._s[2879]! }
    public var Paint_Duplicate: String { return self._s[2880]! }
    public var Passport_Address_Country: String { return self._s[2881]! }
    public var Notification_RenamedChannel: String { return self._s[2883]! }
    public var CheckoutInfo_ErrorPostcodeInvalid: String { return self._s[2884]! }
    public var Group_MessagePhotoUpdated: String { return self._s[2885]! }
    public var Channel_BanUser_PermissionSendMedia: String { return self._s[2886]! }
    public var Conversation_ContextMenuBan: String { return self._s[2887]! }
    public var TwoStepAuth_EmailSent: String { return self._s[2888]! }
    public var MessagePoll_NoVotes: String { return self._s[2889]! }
    public var Passport_Language_is: String { return self._s[2890]! }
    public var Tour_Text5: String { return self._s[2892]! }
    public func Call_GroupFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2894]!, self._r[2894]!, [_1, _2])
    }
    public var Undo_SecretChatDeleted: String { return self._s[2895]! }
    public var SocksProxySetup_ShareQRCode: String { return self._s[2896]! }
    public var LogoutOptions_ChangePhoneNumberText: String { return self._s[2897]! }
    public var Paint_Edit: String { return self._s[2899]! }
    public var Undo_DeletedGroup: String { return self._s[2902]! }
    public var LoginPassword_ForgotPassword: String { return self._s[2903]! }
    public var GroupInfo_GroupNamePlaceholder: String { return self._s[2904]! }
    public func Notification_Kicked(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2905]!, self._r[2905]!, [_0, _1])
    }
    public var Conversation_InputTextCaptionPlaceholder: String { return self._s[2906]! }
    public var AutoDownloadSettings_VideoMessagesTitle: String { return self._s[2907]! }
    public var Passport_Language_uz: String { return self._s[2908]! }
    public var Conversation_PinMessageAlertGroup: String { return self._s[2909]! }
    public var SettingsSearch_Synonyms_Privacy_GroupsAndChannels: String { return self._s[2910]! }
    public var Map_StopLiveLocation: String { return self._s[2912]! }
    public var PasscodeSettings_Help: String { return self._s[2914]! }
    public var NotificationsSound_Input: String { return self._s[2915]! }
    public var Share_Title: String { return self._s[2918]! }
    public var LogoutOptions_Title: String { return self._s[2919]! }
    public var Login_TermsOfServiceAgree: String { return self._s[2920]! }
    public var Compose_NewEncryptedChatTitle: String { return self._s[2921]! }
    public var Channel_AdminLog_TitleSelectedEvents: String { return self._s[2922]! }
    public var Channel_EditAdmin_PermissionEditMessages: String { return self._s[2923]! }
    public var EnterPasscode_EnterTitle: String { return self._s[2924]! }
    public func Call_PrivacyErrorMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2925]!, self._r[2925]!, [_0])
    }
    public var Settings_CopyPhoneNumber: String { return self._s[2926]! }
    public var NotificationsSound_Keys: String { return self._s[2927]! }
    public func Call_ParticipantVersionOutdatedError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2928]!, self._r[2928]!, [_0])
    }
    public var Notification_MessageLifetime1w: String { return self._s[2929]! }
    public var Message_Video: String { return self._s[2930]! }
    public var AutoDownloadSettings_CellularTitle: String { return self._s[2931]! }
    public func PUSH_CHANNEL_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2932]!, self._r[2932]!, [_1])
    }
    public func Notification_JoinedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2935]!, self._r[2935]!, [_0])
    }
    public func PrivacySettings_LastSeenContactsPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2936]!, self._r[2936]!, [_0])
    }
    public var Passport_Language_mk: String { return self._s[2937]! }
    public var CreatePoll_CancelConfirmation: String { return self._s[2938]! }
    public var Conversation_SilentBroadcastTooltipOn: String { return self._s[2940]! }
    public var PrivacyPolicy_Decline: String { return self._s[2941]! }
    public var Passport_Identity_DoesNotExpire: String { return self._s[2942]! }
    public var Channel_AdminLogFilter_EventsRestrictions: String { return self._s[2943]! }
    public var Permissions_SiriAllow_v0: String { return self._s[2945]! }
    public func LOCAL_CHAT_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2946]!, self._r[2946]!, [_1, "\(_2)"])
    }
    public func Notification_RenamedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2947]!, self._r[2947]!, [_0])
    }
    public var Paint_Regular: String { return self._s[2948]! }
    public var ChatSettings_AutoDownloadReset: String { return self._s[2949]! }
    public var SocksProxySetup_ShareLink: String { return self._s[2950]! }
    public var BlockedUsers_SelectUserTitle: String { return self._s[2951]! }
    public var GroupInfo_InviteByLink: String { return self._s[2953]! }
    public var MessageTimer_Custom: String { return self._s[2954]! }
    public var UserInfo_NotificationsDefaultEnabled: String { return self._s[2955]! }
    public var Passport_Address_TypeTemporaryRegistration: String { return self._s[2957]! }
    public var ChatSettings_AutoDownloadUsingWiFi: String { return self._s[2958]! }
    public var Channel_Username_InvalidTaken: String { return self._s[2959]! }
    public var Conversation_ClousStorageInfo_Description3: String { return self._s[2960]! }
    public var Settings_ChatBackground: String { return self._s[2961]! }
    public var Channel_Subscribers_Title: String { return self._s[2962]! }
    public var ApplyLanguage_ChangeLanguageTitle: String { return self._s[2963]! }
    public var Watch_ConnectionDescription: String { return self._s[2964]! }
    public var Wallpaper_ResetWallpapers: String { return self._s[2968]! }
    public var EditProfile_Title: String { return self._s[2969]! }
    public var NotificationsSound_Bamboo: String { return self._s[2971]! }
    public var Channel_AdminLog_MessagePreviousMessage: String { return self._s[2973]! }
    public var Login_SmsRequestState2: String { return self._s[2974]! }
    public var Passport_Language_ar: String { return self._s[2975]! }
    public var SettingsSearch_Synonyms_EditProfile_Title: String { return self._s[2976]! }
    public var Conversation_MessageDialogEdit: String { return self._s[2977]! }
    public func PUSH_AUTH_UNKNOWN(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2978]!, self._r[2978]!, [_1])
    }
    public var Common_Close: String { return self._s[2979]! }
    public var SettingsSearch_Synonyms_Notifications_GroupNotificationsPreview: String { return self._s[2980]! }
    public func Channel_AdminLog_MessageToggleInvitesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2984]!, self._r[2984]!, [_0])
    }
    public var UserInfo_About_Placeholder: String { return self._s[2985]! }
    public func Conversation_FileHowToText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2986]!, self._r[2986]!, [_0])
    }
    public var GroupInfo_Permissions_SectionTitle: String { return self._s[2987]! }
    public var Channel_Info_Banned: String { return self._s[2989]! }
    public func Time_MonthOfYear_m11(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2990]!, self._r[2990]!, [_0])
    }
    public var Appearance_Other: String { return self._s[2991]! }
    public var Passport_Language_my: String { return self._s[2992]! }
    public var Group_Setup_BasicHistoryHiddenHelp: String { return self._s[2993]! }
    public func Time_PreciseDate_m9(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2994]!, self._r[2994]!, [_1, _2, _3])
    }
    public var SettingsSearch_Synonyms_Privacy_PasscodeAndFaceId: String { return self._s[2995]! }
    public var Preview_CopyAddress: String { return self._s[2996]! }
    public func DialogList_SinglePlayingGameSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2997]!, self._r[2997]!, [_0])
    }
    public var KeyCommand_JumpToPreviousChat: String { return self._s[2998]! }
    public var UserInfo_BotSettings: String { return self._s[2999]! }
    public var LiveLocation_MenuStopAll: String { return self._s[3001]! }
    public var Passport_PasswordCreate: String { return self._s[3002]! }
    public var StickerSettings_MaskContextInfo: String { return self._s[3003]! }
    public var Message_PinnedLocationMessage: String { return self._s[3004]! }
    public var Map_Satellite: String { return self._s[3005]! }
    public var Watch_Message_Unsupported: String { return self._s[3006]! }
    public var Username_TooManyPublicUsernamesError: String { return self._s[3007]! }
    public var TwoStepAuth_EnterPasswordInvalid: String { return self._s[3008]! }
    public func Notification_PinnedTextMessage(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3009]!, self._r[3009]!, [_0, _1])
    }
    public var Notifications_ChannelNotificationsHelp: String { return self._s[3010]! }
    public var Privacy_Calls_P2PContacts: String { return self._s[3011]! }
    public var NotificationsSound_None: String { return self._s[3012]! }
    public var AccessDenied_VoiceMicrophone: String { return self._s[3014]! }
    public func ApplyLanguage_ChangeLanguageAlreadyActive(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3015]!, self._r[3015]!, [_1])
    }
    public var Cache_Indexing: String { return self._s[3016]! }
    public var DialogList_RecentTitlePeople: String { return self._s[3018]! }
    public var DialogList_EncryptionRejected: String { return self._s[3019]! }
    public var GroupInfo_Administrators: String { return self._s[3020]! }
    public var Passport_ScanPassportHelp: String { return self._s[3021]! }
    public var Application_Name: String { return self._s[3022]! }
    public var Channel_AdminLogFilter_ChannelEventsInfo: String { return self._s[3023]! }
    public var Passport_Identity_TranslationHelp: String { return self._s[3025]! }
    public func Notification_JoinedGroupByLink(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3026]!, self._r[3026]!, [_0])
    }
    public func DialogList_EncryptedChatStartedOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3027]!, self._r[3027]!, [_0])
    }
    public var Channel_EditAdmin_PermissionDeleteMessages: String { return self._s[3028]! }
    public var Privacy_ChatsTitle: String { return self._s[3029]! }
    public var DialogList_ClearHistoryConfirmation: String { return self._s[3030]! }
    public var SettingsSearch_Synonyms_Data_Storage_ClearCache: String { return self._s[3031]! }
    public var Watch_Suggestion_HoldOn: String { return self._s[3032]! }
    public var SocksProxySetup_RequiredCredentials: String { return self._s[3033]! }
    public var Passport_Address_TypeRentalAgreementUploadScan: String { return self._s[3034]! }
    public var TwoStepAuth_EmailSkipAlert: String { return self._s[3035]! }
    public var Channel_Setup_TypePublic: String { return self._s[3038]! }
    public func Channel_AdminLog_MessageToggleInvitesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3039]!, self._r[3039]!, [_0])
    }
    public var Channel_TypeSetup_Title: String { return self._s[3041]! }
    public var Map_OpenInMaps: String { return self._s[3043]! }
    public func PUSH_PINNED_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3044]!, self._r[3044]!, [_1])
    }
    public var NotificationsSound_Tremolo: String { return self._s[3046]! }
    public func Date_ChatDateHeaderYear(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3047]!, self._r[3047]!, [_1, _2, _3])
    }
    public var ConversationProfile_UnknownAddMemberError: String { return self._s[3048]! }
    public var Passport_PasswordHelp: String { return self._s[3049]! }
    public var Login_CodeExpiredError: String { return self._s[3050]! }
    public var Channel_EditAdmin_PermissionChangeInfo: String { return self._s[3051]! }
    public var Conversation_TitleUnmute: String { return self._s[3052]! }
    public var Passport_Identity_ScansHelp: String { return self._s[3053]! }
    public var Passport_Language_lo: String { return self._s[3054]! }
    public var Camera_FlashAuto: String { return self._s[3055]! }
    public var Common_Cancel: String { return self._s[3056]! }
    public var DialogList_SavedMessagesTooltip: String { return self._s[3057]! }
    public var TwoStepAuth_SetupPasswordTitle: String { return self._s[3058]! }
    public func PUSH_MESSAGE_FWD(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3059]!, self._r[3059]!, [_1])
    }
    public var Conversation_ReportSpamConfirmation: String { return self._s[3060]! }
    public var ChatSettings_Title: String { return self._s[3062]! }
    public var Passport_PasswordReset: String { return self._s[3063]! }
    public var SocksProxySetup_TypeNone: String { return self._s[3064]! }
    public var PhoneNumberHelp_Help: String { return self._s[3066]! }
    public var Checkout_EnterPassword: String { return self._s[3067]! }
    public var Share_AuthTitle: String { return self._s[3069]! }
    public var Activity_UploadingDocument: String { return self._s[3070]! }
    public var State_Connecting: String { return self._s[3071]! }
    public var Profile_MessageLifetime1w: String { return self._s[3072]! }
    public var Conversation_ContextMenuReport: String { return self._s[3073]! }
    public var CheckoutInfo_ReceiverInfoPhone: String { return self._s[3074]! }
    public var AutoNightTheme_ScheduledTo: String { return self._s[3075]! }
    public var AuthSessions_Terminate: String { return self._s[3076]! }
    public var Checkout_NewCard_CardholderNamePlaceholder: String { return self._s[3077]! }
    public var KeyCommand_JumpToPreviousUnreadChat: String { return self._s[3078]! }
    public var PhotoEditor_Set: String { return self._s[3079]! }
    public var EmptyGroupInfo_Title: String { return self._s[3080]! }
    public var Login_PadPhoneHelp: String { return self._s[3081]! }
    public var AutoDownloadSettings_TypeGroupChats: String { return self._s[3083]! }
    public var PrivacyPolicy_DeclineLastWarning: String { return self._s[3085]! }
    public var NotificationsSound_Complete: String { return self._s[3086]! }
    public var SettingsSearch_Synonyms_Privacy_Data_Title: String { return self._s[3087]! }
    public var Group_Info_AdminLog: String { return self._s[3088]! }
    public var GroupPermission_NotAvailableInPublicGroups: String { return self._s[3089]! }
    public var Channel_AdminLog_InfoPanelAlertText: String { return self._s[3090]! }
    public var Conversation_Admin: String { return self._s[3092]! }
    public var Conversation_GifTooltip: String { return self._s[3093]! }
    public var Passport_NotLoggedInMessage: String { return self._s[3094]! }
    public func AutoDownloadSettings_OnFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3095]!, self._r[3095]!, [_0])
    }
    public var Profile_MessageLifetimeForever: String { return self._s[3096]! }
    public var SharedMedia_EmptyTitle: String { return self._s[3098]! }
    public var Channel_Edit_PrivatePublicLinkAlert: String { return self._s[3100]! }
    public var Username_Help: String { return self._s[3101]! }
    public var DialogList_LanguageTooltip: String { return self._s[3103]! }
    public var Map_LoadError: String { return self._s[3104]! }
    public var Login_PhoneNumberAlreadyAuthorized: String { return self._s[3105]! }
    public var Channel_AdminLog_AddMembers: String { return self._s[3106]! }
    public var Notification_Exceptions_NewException: String { return self._s[3107]! }
    public var TwoStepAuth_EmailTitle: String { return self._s[3108]! }
    public var WatchRemote_AlertText: String { return self._s[3109]! }
    public var ChatSettings_ConnectionType_Title: String { return self._s[3112]! }
    public func Settings_CheckPhoneNumberTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3113]!, self._r[3113]!, [_0])
    }
    public var SettingsSearch_Synonyms_Calls_CallTab: String { return self._s[3114]! }
    public var Passport_Address_CountryPlaceholder: String { return self._s[3115]! }
    public func DialogList_AwaitingEncryption(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3116]!, self._r[3116]!, [_0])
    }
    public func Time_PreciseDate_m6(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3117]!, self._r[3117]!, [_1, _2, _3])
    }
    public var Group_AdminLog_EmptyText: String { return self._s[3118]! }
    public var SettingsSearch_Synonyms_Appearance_Title: String { return self._s[3119]! }
    public var AccessDenied_VideoMicrophone: String { return self._s[3121]! }
    public var Conversation_ContextMenuStickerPackAdd: String { return self._s[3122]! }
    public var Cache_ClearNone: String { return self._s[3123]! }
    public var SocksProxySetup_FailedToConnect: String { return self._s[3124]! }
    public var Permissions_NotificationsTitle_v0: String { return self._s[3125]! }
    public func Channel_AdminLog_MessageEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3126]!, self._r[3126]!, [_0])
    }
    public var Passport_Identity_Country: String { return self._s[3127]! }
    public func ChatSettings_AutoDownloadSettings_TypeFile(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3128]!, self._r[3128]!, [_0])
    }
    public func Notification_CreatedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3129]!, self._r[3129]!, [_0])
    }
    public var AccessDenied_Settings: String { return self._s[3130]! }
    public var Passport_Address_TypeUtilityBillUploadScan: String { return self._s[3131]! }
    public var Month_ShortMay: String { return self._s[3132]! }
    public var Compose_NewGroup: String { return self._s[3133]! }
    public var Group_Setup_TypePrivate: String { return self._s[3135]! }
    public var Login_PadPhoneHelpTitle: String { return self._s[3137]! }
    public var Appearance_ThemeDayClassic: String { return self._s[3138]! }
    public var Channel_AdminLog_MessagePreviousCaption: String { return self._s[3139]! }
    public var AutoDownloadSettings_OffForAll: String { return self._s[3140]! }
    public var Privacy_GroupsAndChannels_WhoCanAddMe: String { return self._s[3141]! }
    public var Conversation_typing: String { return self._s[3143]! }
    public var Paint_Masks: String { return self._s[3144]! }
    public var Username_InvalidTaken: String { return self._s[3145]! }
    public var Call_StatusNoAnswer: String { return self._s[3146]! }
    public var TwoStepAuth_EmailAddSuccess: String { return self._s[3147]! }
    public var SettingsSearch_Synonyms_Privacy_BlockedUsers: String { return self._s[3148]! }
    public var Passport_Identity_Selfie: String { return self._s[3149]! }
    public var Login_InfoLastNamePlaceholder: String { return self._s[3150]! }
    public var Privacy_SecretChatsLinkPreviewsHelp: String { return self._s[3151]! }
    public var Conversation_ClearSecretHistory: String { return self._s[3152]! }
    public var NetworkUsageSettings_Title: String { return self._s[3154]! }
    public var Your_cards_security_code_is_invalid: String { return self._s[3156]! }
    public func Notification_LeftChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3158]!, self._r[3158]!, [_0])
    }
    public func Call_CallInProgressMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3159]!, self._r[3159]!, [_1, _2])
    }
    public var SaveIncomingPhotosSettings_From: String { return self._s[3161]! }
    public var Map_LiveLocationTitle: String { return self._s[3162]! }
    public var Login_InfoAvatarAdd: String { return self._s[3163]! }
    public var Passport_Identity_FilesView: String { return self._s[3164]! }
    public var UserInfo_GenericPhoneLabel: String { return self._s[3165]! }
    public var Privacy_Calls_NeverAllow: String { return self._s[3166]! }
    public func Contacts_AddPhoneNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3167]!, self._r[3167]!, [_0])
    }
    public var TwoStepAuth_ConfirmationText: String { return self._s[3168]! }
    public var ChatSettings_AutomaticVideoMessageDownload: String { return self._s[3169]! }
    public func PUSH_CHAT_MESSAGE_VIDEOS(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3170]!, self._r[3170]!, [_1, _2, _3])
    }
    public var Channel_AdminLogFilter_AdminsAll: String { return self._s[3171]! }
    public var Tour_Title2: String { return self._s[3172]! }
    public var Conversation_FileOpenIn: String { return self._s[3173]! }
    public var Checkout_ErrorPrecheckoutFailed: String { return self._s[3174]! }
    public var Wallpaper_Set: String { return self._s[3175]! }
    public var Passport_Identity_Translations: String { return self._s[3177]! }
    public func Channel_AdminLog_MessageChangedChannelAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3178]!, self._r[3178]!, [_0])
    }
    public var Channel_LeaveChannel: String { return self._s[3179]! }
    public func PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3180]!, self._r[3180]!, [_1])
    }
    public var SettingsSearch_Synonyms_Proxy_AddProxy: String { return self._s[3181]! }
    public var PhotoEditor_HighlightsTint: String { return self._s[3182]! }
    public var Passport_Email_Delete: String { return self._s[3183]! }
    public var Conversation_Mute: String { return self._s[3185]! }
    public var Channel_AdminLog_CanSendMessages: String { return self._s[3187]! }
    public func Notification_PassportValuesSentMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3189]!, self._r[3189]!, [_1, _2])
    }
    public var Calls_CallTabDescription: String { return self._s[3190]! }
    public var Passport_Identity_NativeNameHelp: String { return self._s[3191]! }
    public var Common_No: String { return self._s[3192]! }
    public var Weekday_Sunday: String { return self._s[3193]! }
    public var Notification_Reply: String { return self._s[3194]! }
    public var Conversation_ViewMessage: String { return self._s[3195]! }
    public func Checkout_SavePasswordTimeoutAndFaceId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3196]!, self._r[3196]!, [_0])
    }
    public func Map_LiveLocationPrivateDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3197]!, self._r[3197]!, [_0])
    }
    public var SettingsSearch_Synonyms_EditProfile_AddAccount: String { return self._s[3198]! }
    public var Message_PinnedDocumentMessage: String { return self._s[3199]! }
    public var DialogList_TabTitle: String { return self._s[3201]! }
    public var ChatSettings_AutoPlayTitle: String { return self._s[3202]! }
    public var Passport_FieldEmail: String { return self._s[3203]! }
    public var Conversation_UnpinMessageAlert: String { return self._s[3204]! }
    public var Passport_Address_TypeBankStatement: String { return self._s[3205]! }
    public var Passport_Identity_ExpiryDate: String { return self._s[3206]! }
    public var Privacy_Calls_P2P: String { return self._s[3207]! }
    public func CancelResetAccount_Success(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3209]!, self._r[3209]!, [_0])
    }
    public var SocksProxySetup_UseForCallsHelp: String { return self._s[3210]! }
    public func PUSH_CHAT_ALBUM(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3211]!, self._r[3211]!, [_1, _2])
    }
    public var Stickers_ClearRecent: String { return self._s[3212]! }
    public var EnterPasscode_ChangeTitle: String { return self._s[3213]! }
    public var Passport_InfoText: String { return self._s[3214]! }
    public var Checkout_NewCard_SaveInfoEnableHelp: String { return self._s[3215]! }
    public func Login_InvalidPhoneEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3216]!, self._r[3216]!, [_0])
    }
    public func Time_PreciseDate_m3(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3217]!, self._r[3217]!, [_1, _2, _3])
    }
    public var SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChannels: String { return self._s[3218]! }
    public var Passport_Identity_EditDriversLicense: String { return self._s[3219]! }
    public var Conversation_TapAndHoldToRecord: String { return self._s[3221]! }
    public var SettingsSearch_Synonyms_Notifications_BadgeIncludeMutedChats: String { return self._s[3222]! }
    public func Notification_CallTimeFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3223]!, self._r[3223]!, [_1, _2])
    }
    public var Channel_EditAdmin_PermissionInviteViaLink: String { return self._s[3225]! }
    public func Generic_OpenHiddenLinkAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3227]!, self._r[3227]!, [_0])
    }
    public var DialogList_Unread: String { return self._s[3228]! }
    public func PUSH_CHAT_MESSAGE_GIF(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3229]!, self._r[3229]!, [_1, _2])
    }
    public var User_DeletedAccount: String { return self._s[3230]! }
    public func Watch_Time_ShortYesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3231]!, self._r[3231]!, [_0])
    }
    public var UserInfo_NotificationsDefault: String { return self._s[3232]! }
    public var SharedMedia_CategoryMedia: String { return self._s[3233]! }
    public var SocksProxySetup_ProxyStatusUnavailable: String { return self._s[3234]! }
    public var Channel_AdminLog_MessageRestrictedForever: String { return self._s[3235]! }
    public var Watch_ChatList_Compose: String { return self._s[3236]! }
    public var Notifications_MessageNotificationsExceptionsHelp: String { return self._s[3237]! }
    public var AutoDownloadSettings_Delimeter: String { return self._s[3238]! }
    public var Watch_Microphone_Access: String { return self._s[3239]! }
    public var Group_Setup_HistoryHeader: String { return self._s[3240]! }
    public var Activity_UploadingPhoto: String { return self._s[3241]! }
    public var Conversation_Edit: String { return self._s[3243]! }
    public var Group_ErrorSendRestrictedMedia: String { return self._s[3244]! }
    public var Login_TermsOfServiceDecline: String { return self._s[3245]! }
    public var Message_PinnedContactMessage: String { return self._s[3246]! }
    public func Channel_AdminLog_MessageRestrictedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3247]!, self._r[3247]!, [_1, _2])
    }
    public func Login_PhoneBannedEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3248]!, self._r[3248]!, [_1, _2, _3, _4, _5])
    }
    public var Appearance_LargeEmoji: String { return self._s[3249]! }
    public var TwoStepAuth_AdditionalPassword: String { return self._s[3251]! }
    public func PUSH_CHAT_DELETE_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3252]!, self._r[3252]!, [_1, _2])
    }
    public var Passport_Phone_EnterOtherNumber: String { return self._s[3253]! }
    public var Message_PinnedPhotoMessage: String { return self._s[3254]! }
    public var Passport_FieldPhone: String { return self._s[3255]! }
    public var TwoStepAuth_RecoveryEmailAddDescription: String { return self._s[3256]! }
    public var ChatSettings_AutoPlayGifs: String { return self._s[3257]! }
    public var InfoPlist_NSCameraUsageDescription: String { return self._s[3259]! }
    public var Conversation_Call: String { return self._s[3260]! }
    public var Common_TakePhoto: String { return self._s[3262]! }
    public var Channel_NotificationLoading: String { return self._s[3263]! }
    public func Notification_Exceptions_Sound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3264]!, self._r[3264]!, [_0])
    }
    public func PUSH_CHANNEL_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3265]!, self._r[3265]!, [_1])
    }
    public var Permissions_SiriTitle_v0: String { return self._s[3266]! }
    public func Login_ResetAccountProtected_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3267]!, self._r[3267]!, [_0])
    }
    public var Channel_MessagePhotoRemoved: String { return self._s[3268]! }
    public var Common_edit: String { return self._s[3269]! }
    public var PrivacySettings_AuthSessions: String { return self._s[3270]! }
    public var Month_ShortJune: String { return self._s[3271]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Placeholder: String { return self._s[3272]! }
    public var Call_ReportSend: String { return self._s[3273]! }
    public var Watch_LastSeen_JustNow: String { return self._s[3274]! }
    public var Notifications_MessageNotifications: String { return self._s[3275]! }
    public var WallpaperSearch_ColorGreen: String { return self._s[3276]! }
    public var BroadcastListInfo_AddRecipient: String { return self._s[3278]! }
    public var Group_Status: String { return self._s[3279]! }
    public func AutoNightTheme_LocationHelp(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3280]!, self._r[3280]!, [_0, _1])
    }
    public var ShareMenu_ShareTo: String { return self._s[3281]! }
    public var Conversation_Moderate_Ban: String { return self._s[3282]! }
    public func Conversation_DeleteMessagesFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3283]!, self._r[3283]!, [_0])
    }
    public var SharedMedia_ViewInChat: String { return self._s[3284]! }
    public var Map_LiveLocationFor8Hours: String { return self._s[3285]! }
    public func PUSH_PINNED_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3286]!, self._r[3286]!, [_1])
    }
    public func PUSH_PINNED_POLL(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3287]!, self._r[3287]!, [_1, _2])
    }
    public func Map_AccurateTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3289]!, self._r[3289]!, [_0])
    }
    public var Map_OpenInHereMaps: String { return self._s[3290]! }
    public var Appearance_ReduceMotion: String { return self._s[3291]! }
    public func PUSH_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3292]!, self._r[3292]!, [_1, _2])
    }
    public var Channel_Setup_TypePublicHelp: String { return self._s[3293]! }
    public var Passport_Identity_EditInternalPassport: String { return self._s[3294]! }
    public var PhotoEditor_Skip: String { return self._s[3295]! }
    public func Notifications_Exceptions(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[0 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Forward_ConfirmMultipleFiles(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[1 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGES(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[2 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func PUSH_MESSAGE_FWDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[3 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func StickerPack_RemoveStickerCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[4 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[5 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedMessages(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[6 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Video(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[7 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Seconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[8 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_AddMaskCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[9 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortHours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[10 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_StatusSubscribers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[11 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[12 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortSeconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[13 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_File(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[14 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Passport_Scans(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[15 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_ShortSeconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[16 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_SelectedChats(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[17 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_PHOTOS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[18 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func MessageTimer_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[19 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteExpires_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[20 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func InviteText_ContactsCountText(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[21 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedFiles(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[22 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[23 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_VIDEOS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[24 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func Map_ETAMinutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[25 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_ShortMinutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[26 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Map_ETAHours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[27 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LiveLocation_MenuChatsCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[28 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[29 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notifications_ExceptionMuteExpires_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[30 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteFor_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[31 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendGif(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[32 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Invitation_Members(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[33 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Generic(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[34 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_RemoveMaskCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[35 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Watch_UserInfo_Mute(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[36 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_ShortMinutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[37 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedVideos(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[38 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_DeleteItemsConfirmation(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[39 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Media_ShareItem(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[40 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Contacts_ImportersCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[41 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PrivacyLastSeenSettings_AddUsers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[42 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessagePoll_VotedCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[43 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Watch_LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[44 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedAuthorsOthers(_ selector: Int32, _ _0: String, _ _1: String) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[45 * 6 + Int(form.rawValue)]!, _0, _1)
    }
    public func PUSH_CHANNEL_MESSAGE_FWDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[46 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func GroupInfo_ParticipantCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[47 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_PHOTOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[48 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func MessageTimer_Weeks(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[49 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_PHOTOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[50 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Media_SharePhoto(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[51 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_ROUNDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[52 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func MessageTimer_ShortDays(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[53 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_StickerCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[54 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[55 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func UserCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[56 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendPhoto(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[57 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Media_ShareVideo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[58 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_VIDEOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[59 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Call_Seconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[60 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_StatusOnline(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[61 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedGifs(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[62 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedContacts(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[63 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[64 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Photo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[65 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_FWDS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[66 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func MessageTimer_ShortWeeks(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[67 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[68 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Months(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[69 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Watch_LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[70 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedVideoMessages(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[71 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func QuickSend_Photos(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[72 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedLocations(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[73 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Wallpaper_DeleteConfirmation(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[74 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_StatusMembers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[75 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notifications_ExceptionMuteExpires_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[76 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MessageTimer_Years(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[77 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Call_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[78 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteExpires_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[79 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHANNEL_MESSAGE_ROUNDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[80 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func PUSH_MESSAGES(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[81 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func LiveLocationUpdated_MinutesAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[82 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Conversation_LiveLocationMembersCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[83 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedPolls(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[84 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func CreatePoll_AddMoreOptions(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[85 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PasscodeSettings_FailedAttempts(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[86 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func SharedMedia_Link(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[87 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[88 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Chat_DeleteMessagesConfirmation(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[89 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedAudios(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[90 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteFor_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[91 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendVideo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[92 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func AttachmentMenu_SendItem(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[93 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ChatList_DeleteConfirmation(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[94 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ServiceMessage_GameScoreSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[95 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_MESSAGE_VIDEOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[96 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func ServiceMessage_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[97 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func DialogList_LiveLocationChatsCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[98 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGES(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[99 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func Notification_GameScoreExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[100 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func Notification_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[101 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func MuteExpires_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[102 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedPhotos(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[103 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func PUSH_CHAT_MESSAGE_ROUNDS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[104 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func Notifications_ExceptionMuteExpires_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[105 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func StickerPack_AddStickerCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[106 * 6 + Int(form.rawValue)]!, stringValue)
    }
    public func ForwardedStickers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        let stringValue = presentationStringsFormattedNumber(value, self.groupingSeparator)
        return String(format: self._ps[107 * 6 + Int(form.rawValue)]!, stringValue)
    }
        
    init(primaryComponent: PresentationStringsComponent, secondaryComponent: PresentationStringsComponent?, groupingSeparator: String) {
        self.primaryComponent = primaryComponent
        self.secondaryComponent = secondaryComponent
        self.groupingSeparator = groupingSeparator
        
        self.baseLanguageCode = secondaryComponent?.languageCode ?? primaryComponent.languageCode
        
        let languageCode = primaryComponent.pluralizationRulesCode ?? primaryComponent.languageCode
        var rawCode = languageCode as NSString
        var range = rawCode.range(of: "_")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        range = rawCode.range(of: "-")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        rawCode = rawCode.lowercased as NSString
        var lc: UInt32 = 0
        for i in 0 ..< rawCode.length {
            lc = (lc << 8) + UInt32(rawCode.character(at: i))
        }
        self.lc = lc

        var _s: [Int: String] = [:]
        var _r: [Int: [(Int, NSRange)]] = [:]
        
        let loadedKeyMapping = keyMapping
        
        let sIdList: [Int] = loadedKeyMapping.0
        let sKeyList: [String] = loadedKeyMapping.1
        let sArgIdList: [Int] = loadedKeyMapping.2
        for i in 0 ..< sIdList.count {
            _s[sIdList[i]] = getValue(primaryComponent, secondaryComponent, sKeyList[i])
        }
        for i in 0 ..< sArgIdList.count {
            _r[sArgIdList[i]] = extractArgumentRanges(_s[sArgIdList[i]]!)
        }
        self._s = _s
        self._r = _r

        var _ps: [Int: String] = [:]
        let pIdList: [Int] = loadedKeyMapping.3
        let pKeyList: [String] = loadedKeyMapping.4
        for i in 0 ..< pIdList.count {
            for form in 0 ..< 6 {
                _ps[pIdList[i] * 6 + form] = getValueWithForm(primaryComponent, secondaryComponent, pKeyList[i], PluralizationForm(rawValue: Int32(form))!)
            }
        }
        self._ps = _ps
    }
}

