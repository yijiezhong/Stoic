// 每 30 秒向 native host 查询专注状态；host 不可用时回退到手动配置的黑名单。
const RULE_ID_BASE = 1000;
const HOST_NAME = "com.zhizhi.stoic.host";

let manualHosts = [];
let lastAppliedKey = "";

function applyRules(hosts) {
  const key = hosts.join("|");
  if (key === lastAppliedKey) return;
  lastAppliedKey = key;

  chrome.declarativeNetRequest.getDynamicRules().then(function (existing) {
    const removeRuleIds = existing.map(function (rule) { return rule.id; });
    const addRules = hosts.map(function (host, index) {
      return {
        id: RULE_ID_BASE + index,
        priority: 1,
        action: { type: "block" },
        condition: { urlFilter: "||" + host + "^", resourceTypes: ["main_frame"] }
      };
    });
    chrome.declarativeNetRequest.updateDynamicRules({ removeRuleIds: removeRuleIds, addRules: addRules });
  });
}

function queryHost() {
  chrome.runtime.sendNativeMessage(HOST_NAME, { type: "state" }, function (response) {
    if (chrome.runtime.lastError || !response || !response.available) {
      applyRules(manualHosts);
      return;
    }
    if (response.focusing) {
      applyRules(response.blockedHosts || []);
    } else {
      applyRules([]);
    }
  });
}

chrome.storage.local.get("blockedHosts").then(function (data) {
  manualHosts = data.blockedHosts || [];
});

chrome.storage.onChanged.addListener(function (changes) {
  if (changes.blockedHosts) {
    manualHosts = changes.blockedHosts.newValue || [];
  }
});

chrome.runtime.onInstalled.addListener(function () {
  chrome.alarms.create("stoic-poll", { periodInMinutes: 0.5 });
  queryHost();
});

chrome.runtime.onStartup.addListener(function () {
  chrome.alarms.create("stoic-poll", { periodInMinutes: 0.5 });
  queryHost();
});

chrome.alarms.onAlarm.addListener(function (alarm) {
  if (alarm.name === "stoic-poll") queryHost();
});
