import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = relative => fs.readFileSync(path.join(projectDir, relative), "utf8");
const escape = value => value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
let nextReferent = 1;

function properties(name, source, disabled = false) {
  return `<Properties><bool name="Archivable">true</bool>${source === undefined ? "" : `<bool name="Disabled">${disabled}</bool><ProtectedString name="Source">${escape(source)}</ProtectedString>`}<string name="Name">${escape(name)}</string></Properties>`;
}

function item(className, name, children = "", source) {
  const referent = `RBX${nextReferent++}`;
  return `<Item class="${className}" referent="${referent}">${properties(name, source)}${children}</Item>`;
}

const config = read("src/shared/Config.luau");
const quests = read("src/shared/Quests.luau");
const world = read("src/server/World.luau");
const model = read("src/server/Model.luau");
const store = read("src/server/Store.luau");
const receipt = read("src/server/Receipt.luau");
const commerce = read("src/server/Commerce.luau");
const main = read("src/server/Main.server.luau");
const client = read("src/client/Client.client.luau");
const commerceSpec = read("tests/CommerceSpec.luau");

const allSource = [config, quests, model, store, receipt, commerce, world, main, client, commerceSpec].join("\n");
const receiptAssignments = (allSource.match(/ProcessReceipt\s*=/g) || []).length;
if (receiptAssignments !== 1) throw new Error(`Expected one ProcessReceipt assignment, found ${receiptAssignments}`);
if (commerce.includes("PromptProductPurchaseFinished:Connect")) throw new Error("Developer products must not be granted from PromptProductPurchaseFinished");
for (const required of ["UpdateAsync", "PurchaseId", "NotProcessedYet", "PurchaseGranted"]) {
  if (!commerce.concat(store).includes(required)) throw new Error(`Missing commerce safeguard: ${required}`);
}
for (const required of ["Attack", "Pulse", "ClaimDaily", "UnlockZone", "Rebirth", "UpgradeMove"]) {
  if (!main.includes(`${required} = true`)) throw new Error(`Missing server action allowlist entry: ${required}`);
}

// Reach and cooldowns live in Config so the HUD cannot promise what the server refuses.
for (const required of ["AttackRange", "PulseRange", "Cooldowns"]) {
  if (!config.includes(required)) throw new Error(`Config must define ${required}`);
}
for (const [label, source] of [["server", main], ["client", client]]) {
  if (!source.includes("Config.AttackRange")) throw new Error(`The ${label} must read Config.AttackRange, not a local copy`);
}
if (!client.includes('require(remotes:WaitForChild("Config"))')) {
  throw new Error("The client must require the shared Config module");
}

// The game has to answer "what am I supposed to do" in three places: the shared quest
// chain, the HUD banner, and the stone signs standing in the world.
const questCount = (quests.match(/\bId = "/g) || []).length;
if (questCount < 6) throw new Error(`Expected a quest chain, found ${questCount} quests`);
for (const [label, source] of [["server", main], ["client", client]]) {
  if (!source.includes("Quests")) throw new Error(`The ${label} must read the shared Quests module`);
}
if (!main.includes("World.setObjective")) throw new Error("The server must push the active quest to the world signs");
if (!world.includes("SurfaceGui")) throw new Error("The world must carry readable signs, not just floating labels");
if (!world.includes("signBoards")) throw new Error("The world must collect its quest signs");
if (!world.includes("function World.setObjective")) throw new Error("The world must expose setObjective");
// A lit SurfaceGui in a night map is an unreadable one; this is why signs looked blank.
if (!world.includes("LightInfluence = 0")) throw new Error("Sign faces must not be dimmed by scene lighting");

// Enemies hold a post and disengage. Without a leash they chase across the whole map.
for (const required of ["Engage", "Leash", "RegenPerSecond"]) {
  if (!config.includes(required)) throw new Error(`Config must define Aggro.${required}`);
}
for (const required of ["Chasing", "Returning", "Idle"]) {
  if (!main.includes(`"${required}"`)) throw new Error(`Enemy state machine is missing ${required}`);
}

// Move ranks are bought on the server and capped there, never trusted from the client.
if (!main.includes("upgradeMove")) throw new Error("The server must own ability rank purchases");
if (!model.includes("abilityCost")) throw new Error("Model must own the rank cost curve");

// Every ability needs a key, and Soul Strike also needs pointer input.
for (const [action, key] of [["SoulAttack", "F"], ["SoulPulse", "Q"], ["SoulStep", "E"]]) {
  if (!client.includes(`BindAction("${action}"`)) throw new Error(`Client is missing the ${action} binding`);
  if (!client.includes(`Enum.KeyCode.${key}`)) throw new Error(`${action} must be bound to ${key}`);
}
for (const required of ["UserInputService.InputBegan", "Enum.UserInputType.MouseButton1", "Enum.UserInputType.Touch"]) {
  if (!client.includes(required)) throw new Error(`Client is missing pointer input: ${required}`);
}
// A silent ability is indistinguishable from a broken one.
for (const kind of ["Swing", "Miss", "Cooling"]) {
  if (!main.includes(`Kind = "${kind}"`)) throw new Error(`Server must send the ${kind} effect so failed input still reads as input`);
}

const remotes = ["Action", "State", "Notice", "Offer", "FX"].map(name => item("RemoteEvent", name)).join("");
const replicated = item("ReplicatedStorage", "ReplicatedStorage",
  item("Folder", "SoulGrind", item("ModuleScript", "Config", "", config) + item("ModuleScript", "Quests", "", quests) + remotes));
const serverScripts = item("ServerScriptService", "ServerScriptService",
  item("ModuleScript", "World", "", world) +
  item("ModuleScript", "Model", "", model) +
  item("ModuleScript", "Receipt", "", receipt) +
  item("ModuleScript", "Store", "", store) +
  item("ModuleScript", "Commerce", "", commerce) +
  item("Script", "Main", "", main));
const starterPlayer = item("StarterPlayer", "StarterPlayer",
  item("StarterPlayerScripts", "StarterPlayerScripts", item("LocalScript", "Client", "", client)));
const serverStorage = item("ServerStorage", "ServerStorage",
  item("Folder", "SoulGrindTests", item("ModuleScript", "CommerceSpec", "", commerceSpec)));
const workspace = item("Workspace", "Workspace");
// Technology is read-only to scripts, so it has to be pinned here. Anything below
// ShadowMap silently ignores Atmosphere and the environment scales, which is how a
// carefully lit scene still ends up looking like a black screen.
const lighting = `<Item class="Lighting" referent="RBX${nextReferent++}"><Properties><bool name="Archivable">true</bool><string name="Name">Lighting</string><token name="Technology">3</token><bool name="GlobalShadows">true</bool></Properties></Item>`;

const xml = `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4"><External>null</External><External>nil</External>${workspace}${lighting}${replicated}${serverScripts}${starterPlayer}${serverStorage}</roblox>`;
if (!xml.includes('name="Technology"')) throw new Error("The place file must pin Lighting.Technology");
const output = path.join(projectDir, "dist", "SoulGrind_Underworld_Rising.rbxlx");
fs.writeFileSync(output, xml, "utf8");
console.log(`Built ${output} (${xml.length.toLocaleString()} characters)`);
