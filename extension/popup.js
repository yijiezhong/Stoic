const textarea = document.getElementById("hosts");
const status = document.getElementById("status");

chrome.storage.local.get("blockedHosts").then(function (data) {
  textarea.value = (data.blockedHosts || []).join("\n");
});

document.getElementById("save").addEventListener("click", async function () {
  const hosts = textarea.value
    .split("\n")
    .map(function (line) { return line.trim(); })
    .filter(Boolean);
  await chrome.storage.local.set({ blockedHosts: hosts });
  status.textContent = "已保存 " + hosts.length + " 个站点";
});
