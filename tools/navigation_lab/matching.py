"""Conservative intent and feature selection; never routes or executes anything."""
import re
from simulator import FEATURES, baseline
from ollama_client import interpret as model_interpret

# Terms here are lab-only evidence for the model's proposal, not new app routes.
EVIDENCE = {
 'qr_scan': r'\bqr\b|掃碼|掃描|二維碼', 'activity_information':r'活動|events?|activit(?:y|ies)',
 'library_services':r'圖書|借書|借閱|library|books?', 'municipal_applications':r'申辦|application|permit',
 'ticket_wallet':r'票夾|票券|wallet|tickets?', 'settings':r'設定|settings?|preferences?',
 'language_settings':r'語言|language|locale', 'account':r'帳戶|帳號|account|profile',
 'personal_information':r'基本資料|個人資料|personal (?:info|information|details)|profile information',
 'messages':r'訊息|消息|通知訊息|messages?|inbox', 'home':r'首頁|主頁|home',
 'services':r'市政服務|服務|services?', 'perks':r'優惠|coupon|perks?', 'bills':r'帳務|帳單|繳費|付款|bills?|payment\s+(?:history|records?)|fees?',
 'fee_search':r'搜尋繳費|繳費項目|fee search|search (?:for )?(?:a )?(?:fee|bill)',
 'feedback':r'意見回饋|回饋|建議|feedback', 'startup_page':r'起始頁|啟動頁|start(?:up|ing)? (?:page|screen)',
 'invoice_receipt':r'載具|發票|invoice|receipt', 'online_police':r'警政服務|police services?',
 'service_catalog':r'我的服務|服務清單|service catalog', 'citizen_report':r'有話要說|市民陳情|citizen report',
 'disaster_report':r'災情|災害|disaster', 'counter_calling':r'叫號|櫃檯|counter',
 'subscription':r'訂閱|subscription', 'surrounding_services':r'周邊|附近服務|surrounding services?',
 'police_report':r'警政報案|報案|police report', 'faq':r'常見問題|faq|frequently asked questions',
}
ACTION = re.compile(r'(?:完成|進行|幫我|我要|請|立即|直接)?\s*(?:付款|支付|繳費|刷卡|提交|送出|申請|更改|修改|刪除|取消預約|結清|付清|刪掉|移除|撥打|打電話|打給|買一|買票|改成|開啟相機|啟動相機|啟用定位|分享位置|開啟外部連結|打開外部連結|預約|續借|購買|報名)(?!紀錄|记录|項目|服務|方式|資訊|資訊頁|頁面)|\b(?:pay|submit|send|change|update|delete|call|purchase|buy|reserve|renew|cancel|enable|activate|settle|transfer|remove)\b|\bopen (?:an? )?external (?:url|link)\b',re.I)
VIEW = re.compile(r'帶我去|前往|導航到|查看|檢視|查詢|開啟|打開|我要查|查一下|看看|瞧|看|找|哪裡|哪邊|在哪|哪個|哪裡有|位置|頁面|紀錄|記錄|歷史|\b(?:view|see|show|find|where|locate|open|history|records?|look|browse)\b',re.I)
# Explicit view nouns must not be mistaken for payment execution; mixed actions still reject.
PAYMENT_NOUN = re.compile(r'(?:繳費|付款|支付)(?=紀錄|記錄|歷史|項目|資訊|頁面|方式)|\bpayment\s+(?:history|records?|information|page|options?)\b',re.I)
DETAIL = re.compile(r'詳細|詳情|特定|某一|\bspecific\b|\bdetails?\b|\bparticular\b', re.I)

UNSUPPORTED = re.compile(r'天氣|氣象|公車|捷運|停車|地震|時刻表|選舉|\b(?:weather|forecast|parking|timetable|train|transit|earthquake|election)\b', re.I)
MULTIPLE = re.compile(r'或|或者|\bor\b|以及|還有|\band\b|並且|然後|跟',re.I)

def deterministic_intent(query):
    text=PAYMENT_NOUN.sub('PAYMENT_NOUN',query)
    action=bool(ACTION.search(text)); view=bool(VIEW.search(query))
    if action:
        mixed=view and bool(re.search(r'並|再|然後|先|\band\b|\bthen\b',query,re.I))
        return 'mixed_browse_and_action' if mixed else 'perform_real_action'
    if UNSUPPORTED.search(query): return 'unsupported'
    if MULTIPLE.search(query): return 'ambiguous'
    return 'browse_or_navigate' if view else 'ambiguous'

def intent(query):
    """Compatibility adapter for the existing source-only preview validator."""
    kind=deterministic_intent(query)
    if kind in ('perform_real_action','mixed_browse_and_action'): return 'action'
    if kind=='ambiguous' and MULTIPLE.search(query): return 'multiple'
    return 'view' if kind=='browse_or_navigate' else 'uncertain'

def exact(query):
    """Find unambiguous longest non-overlapping audited name/alias mentions."""
    q=query.casefold(); hits=[]
    for f in FEATURES.values():
        for term in set([f['display_name'],*f.get('aliases',[]), *({'fee_search':['繳費項目']}.get(f['id'],[]))]):
            if len(term)<2: continue
            pattern=re.escape(term.casefold())
            if term.isascii(): pattern=r'(?<![a-z0-9])'+pattern+r'(?![a-z0-9])'
            for m in re.finditer(pattern,q): hits.append((m.start(),m.end(),f['id']))
    selected=[]
    for hit in sorted(hits,key=lambda x:(-(x[1]-x[0]),x[0])):
        if any(hit[0]>=a and hit[1]<=b for a,b,_ in selected): continue
        selected.append(hit)
    ids={x[2] for x in selected}
    # Account settings is a compound, not two requested destinations.
    if ids=={'account','settings'} and re.search(r'account\s+settings|settings?\s+for\s+(?:my\s+)?account|帳(?:戶|號).{0,4}設定',q): return 'settings'
    if ids=={'language_settings','settings'} and re.search(r'language\s+settings',q): return 'language_settings'
    if len(ids)>1: return '__ambiguous__'
    return next(iter(ids)) if ids else None

def hybrid(query, proposed=None, call_model=True, model_result=None):
    """Classify first, then resolve an audited feature. The result grants no action."""
    kind=deterministic_intent(query)
    def stop(intent_name,decision,reason):
        return {'intent':intent_name,'feature_id':None,'decision':decision,'support':'unsupported' if intent_name=='unsupported' else 'unknown','action_allowed':False,'reason':reason}
    if kind in ('perform_real_action','mixed_browse_and_action'):
        return stop(kind,'rejected','Real actions cannot be performed in this read-only lab.')
    if kind=='unsupported': return stop(kind,'clarify','The requested topic is not in the audited feature catalog.')
    if kind=='ambiguous': return stop(kind,'clarify','Please specify one destination and whether you want to view it.')
    if call_model and model_result is None:
        try: model_result=model_interpret(query,FEATURES)
        except Exception as exc: return stop('ambiguous','clarify','Local intent model unavailable: '+str(exc))
    if model_result is not None:
        if not isinstance(model_result,dict) or set(model_result)!={'intent','feature_id'} or model_result['intent'] not in ('browse_or_navigate','perform_real_action','mixed_browse_and_action','unsupported','ambiguous'):
            return stop('ambiguous','clarify','Invalid local intent response.')
        candidate=model_result['feature_id']
        if candidate is not None and (not isinstance(candidate,str) or candidate not in FEATURES): return stop('ambiguous','rejected','Invalid feature ID.')
        mkind=model_result['intent']
        if mkind in ('perform_real_action','mixed_browse_and_action'): return stop(mkind,'rejected','The request may involve a real action; no action is allowed.')
        if mkind in ('unsupported','ambiguous'): return stop(mkind,'clarify','The local model could not identify one supported read-only destination.')
        proposed=candidate
    feature=exact(query)
    if feature=='__ambiguous__': return stop('ambiguous','clarify','More than one feature was mentioned.')
    if feature:
        if proposed is not None and proposed not in FEATURES: return stop('ambiguous','rejected','Invalid feature ID.')
        # Disagreement is not silently resolved by a model or an isolated name.
        if model_result is not None and proposed!=feature: return stop('ambiguous','clarify','Feature name and local interpretation disagree; please specify the destination.')
        return {'intent':'browse_or_navigate','feature_id':feature,'decision':'matched','support':'catalog_feature','action_allowed':False,'source':'name_or_alias'}
    if proposed is None: return stop('ambiguous','clarify','No supported feature identified.')
    if not isinstance(proposed,str) or proposed not in FEATURES: return stop('ambiguous','rejected','Invalid feature ID.')
    if not re.search(EVIDENCE.get(proposed,r'(?!)'),query,re.I): return stop('ambiguous','clarify','The proposal lacks feature-specific evidence.')
    return {'intent':'browse_or_navigate','feature_id':proposed,'decision':'matched','support':'catalog_feature','action_allowed':False,'source':'model_with_evidence'}
