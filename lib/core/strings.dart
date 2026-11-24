/// 全应用中文文案集中表。UI 层不允许出现裸字符串。
class S {
  const S._();

  static const appName = '校园口袋';
  static const appSlogan = '统一认证 · 课表 · 专注 · 校园服务';

  // 导航
  static const tabHome = '首页';
  static const tabSchedule = '课表';
  static const tabFocus = '专注';
  static const tabCampus = '校园';
  static const tabMore = '更多';

  // 通用
  static const retry = '重试';
  static const confirm = '确定';
  static const cancel = '取消';
  static const save = '保存';
  static const delete = '删除';
  static const close = '关闭';
  static const loading = '加载中…';
  static const copy = '复制';
  static const copied = '已复制到剪贴板';
  static const copyFailed = '复制失败，请重试';

  // 登录
  static const loginTitle = '统一身份认证';
  static const loginSubtitle = '使用学校统一身份认证账号登录；App 不保存密码，只在本机保存会话凭据。';
  static const username = '学号 / 工号';
  static const usernameHint = '请输入学号或工号';
  static const password = '密码';
  static const passwordHint = '请输入密码';
  static const captcha = '验证码';
  static const captchaHint = '请输入图中字符';
  static const loginAction = '登录';
  static const loggingIn = '正在登录…';
  static const logout = '退出登录';
  static const logoutConfirmTitle = '退出登录？';
  static const logoutConfirmBody = '将清除本机保存的会话凭据与 Cookie，需要重新登录才能访问校园服务。';
  static const loginSuccess = '登录成功';
  static const notLoggedIn = '未登录';
  static const needLogin = '登录后可用';
  static const loginRequiredTitle = '还没有登录';
  static const loginRequiredBody = '登录统一身份认证后，课表、校园卡、电费等校园服务才能真正跑起来。';
  static const webLoginFallback = '用网页登录';
  static const webLoginTip = '遇到短信验证、设备绑定等无法自动完成的步骤时，用网页登录一次，随后自动同步 Cookie。';
  static const usernameEmpty = '请先输入学号或工号';
  static const passwordEmpty = '请先输入密码';

  // 首页
  static const homeGreetingMorning = '早上好';
  static const homeGreetingNoon = '中午好';
  static const homeGreetingAfternoon = '下午好';
  static const homeGreetingEvening = '晚上好';
  static const todayTimeline = '今天的时间轴';
  static const todayNoCourse = '今天没有课，安排点自己的事吧';
  static const quickAccess = '快捷入口';
  static const campusCard = '校园卡';
  static const electricity = '宿舍电费';
  static const focusToday = '今日专注';
  static const minuteUnit = '分钟';
  static const balanceUnknown = '未获取';

  // 课表
  static const scheduleTitle = '课表';
  static const weekPrefix = '第';
  static const weekSuffix = '周';
  static const thisWeek = '本周';
  static const noCourseThisWeek = '这周还没有课，点右下角添加一条吧';
  static const addCourse = '添加课程';
  static const editCourse = '编辑课程';
  static const courseName = '课程名称';
  static const courseTeacher = '任课教师';
  static const courseLocation = '上课地点';
  static const courseWeekday = '星期';
  static const coursePeriod = '节次';
  static const courseWeeks = '起止周';
  static const deleteCourseTitle = '删除这门课？';
  static const deleteCourseBody = '删除后不会影响学校教务系统的数据，只影响本机课表。';
  static const courseSaved = '已保存';
  static const semesterStart = '开学第一周的周一';
  static const semesterStartTip = '用于换算「第几周」，设置一次即可。';

  // 专注
  static const focusTitle = '专注';
  static const focusStart = '开始专注';
  static const focusPause = '暂停';
  static const focusResume = '继续';
  static const focusStop = '结束';
  static const focusRunning = '专注中';
  static const focusPaused = '已暂停';
  static const focusIdle = '准备开始';
  static const focusTodayTitle = '今日专注';
  static const focusWeekTitle = '最近 7 天';
  static const focusTagStudy = '学习';
  static const focusTagWork = '工作';
  static const focusTagRead = '阅读';
  static const focusRecords = '专注记录';
  static const noFocusRecord = '还没有专注记录，先开始第一个 25 分钟吧';
  static const focusFinished = '这次专注完成了';

  // 校园
  static const campusTitle = '校园';
  static const campusCardBalance = '校园卡余额';
  static const campusCardDetail = '消费流水';
  static const electricityBalance = '电费余额';
  static const librarySeat = '图书馆座位';
  static const portalEntry = '门户网站';
  static const portalEntryTip = '带着已登录的会话直接打开门户，不用再输一次密码。';
  static const apiNotCalibrated = '接口待校准';
  static const apiNotCalibratedBody = '这个数据来自门户业务接口，需要在真机上抓一次包才能对上字段。可以先用「接口调试台」把返回贴回来，我们下一版直接接上。';
  static const openDebugConsole = '去调试台';
  static const libraryNotConfigured = '图书馆系统地址还没配置';

  // 更多
  static const moreTitle = '更多';
  static const sectionAccount = '账号';
  static const sectionAppearance = '外观';
  static const sectionData = '数据与网络';
  static const sectionAbout = '关于';
  static const appearance = '主题与外观';
  static const themeMode = '主题模式';
  static const themeSystem = '跟随系统';
  static const themeLight = '浅色';
  static const themeDark = '深色';
  static const pureBlack = '深色下使用纯黑背景';
  static const dynamicColor = '跟随壁纸取色';
  static const dynamicColorTip = 'Android 12 及以上支持；取不到壁纸色时回落种子色。';
  static const seedColor = '种子色';
  static const colorType = '配色方案';
  static const textScale = '字体大小';
  static const cookieManager = 'Cookie 管理';
  static const apiDebug = '接口调试台';
  static const about = '关于';
  static const clearCookies = '清空 Cookie 与会话';
  static const clearCookiesBody = '清空后需要重新登录统一身份认证。';
  static const cookiesCleared = '已清空会话';
  static const noCookie = '本机还没有保存任何 Cookie，先登录一次吧';
  static const version = '版本';
  static const privacy = '隐私说明';
  static const privacyBody = '所有凭据与数据只保存在本机，不上传任何服务器；App 不保存密码，只保存会话 Cookie。';
  static const openSource = '开源致谢';
  static const openSourceBody = '界面与技术栈参考 Kazumi，功能设计参考 ZZUPocket。';
  static const debugTitle = '接口调试台';
  static const debugPathHint = '输入以 / 开头的门户路径，例如 /ywtb-portal/standard/index.html';
  static const debugSend = '发送';
  static const debugEmpty = '还没有请求';
  static const debugTooLong = '返回内容太长，已截断显示';

  // 错误文案
  static const errNetwork = '网络好像不通，检查一下连接再试';
  static const errTimeout = '请求超时了，稍后再试';
  static const errUnauthorized = '登录已失效，请重新登录';
  static const errServer = '学校服务器出问题了，稍后再试';
  static const errUnknown = '出了点问题，稍后再试';
  static const errParse = '返回的数据看不懂，可能是门户改版了';
  static const errCasPassword = '账号或密码不对，再确认一下';
  static const errCasCaptcha = '需要输入验证码';
  static const errCasNeedManual = '这一步需要人工完成（短信或设备绑定），请用网页登录';
  static const errCasUnknown = '登录没成功，换个方式试试';

  // 网页登录 / 会话同步
  static const syncSession = '同步会话';
  static const syncing = '同步中…';
  static const webSyncHint = '在网页里登录完成后，点右边把会话收回来；落在校内页面时会自动同步一次。';
  static const sessionSynced = '登录成功，会话已接管';
  static const sessionNotAccepted = '抓到了 Cookie，但服务端不认这次会话，请重新登录一次';
  static const cookieImported = '已导入 Cookie';

  // 扫一扫
  static const scanTitle = '扫一扫';
  static const scanHint = '对准签到二维码；校内链接会带着已登录的会话直接打开';
  static const scanCameraDenied = '没有相机权限，去系统设置里打开再回来';
  static const scanRescan = '重新扫描';
  static const scanOpen = '用内置浏览器打开';
  static const scanEmpty = '还没扫到内容';
  static const scanManual = '手动输入链接';
  static const scanManualHint = '粘贴签到页地址，例如从钉钉里复制的链接';
  static const scanEngineSmart = '智能引擎';
  static const scanEngineWeChat = '微信引擎';
  static const scanSlowSwitch = '识别较慢，已切换微信引擎';
  static const scanWeChatTeleHint = '远距离二维码请用长焦';
  static const scanWeChatInitFailed = '微信引擎初始化失败，已回退智能引擎';

  // 教务导入
  static const importTitle = '从教务导入课表';
  static const importIntro = '先自动登录教务，再按金智的两套标准接口逐个试，能对上的那个直接把课表写进来。';
  static const importBase = '教务系统地址';
  static const importYear = '学年（如 2026）';
  static const importTerm = '学期代码（3=秋 12=春 16=夏）';
  static const importRun = '开始导入';
  static const importRunning = '正在导入…';
  static const importDone = '导入完成';
  static const importEmpty = '没认出课表数据';
  static const importProbe = '接口探测结果';
  static const importPaste = '粘贴 JSON 导入';
  static const importPasteHint = '把调试台里课表接口的返回整个贴进来';
  static const importPasteAction = '解析并导入';
  static const importOverwrite = '导入会覆盖之前从教务同步的课程（手填的课程保留）';

  // 诊断
  static const diagTitle = '诊断';
  static const diagSession = '会话状态';
  static const diagCookies = '本机 Cookie';
  static const diagJar = 'cookie jar';
  static const diagRaw = '原始账本';
  static const diagCheck = '重新探测';
  static const diagLogs = '最近日志';
  static const diagAlive = '可用';
  static const diagDead = '不可用';

}
