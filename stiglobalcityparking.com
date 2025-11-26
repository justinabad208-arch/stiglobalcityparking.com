<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
 
  <link rel="stylesheet" href="style.css">
 
  <title>STI Parking Global City</title>
 
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link
    href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;700&display=swap"
    rel="stylesheet"
  />
 
  <!-- QR Scanner Library -->
  <script src="https://unpkg.com/html5-qrcode@2.3.7/html5-qrcode.min.js"></script>
 
  <!-- QR Code Generator -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
</head>
 
<body>
  <header>
    <img src="LOGO.png" width="60">
    <h1>STI <span>PARKING</span> Global City</h1>
  </header>
 
  <nav>
    <div class="tab active" data-tab="login" onclick="showTab('login')">Login</div>
    <div class="tab hidden" data-tab="home" onclick="showTab('home')">Home</div>
    <div class="tab hidden" data-tab="dashboard" onclick="showTab('dashboard')">Dashboard</div>
    <div class="tab hidden" data-tab="generate" onclick="showTab('generate')">Generate QR Code</div>
    <div class="tab hidden" data-tab="scan" onclick="showTab('scan')">Scan QR Code</div>
  </nav>
 
  <main>
    <!-- LOGIN -->
    <section id="login" class="tab-content active">
      <h2>Login to STI PARKING GLOBAL CITY</h2>
      <form id="loginForm" onsubmit="event.preventDefault(); login();">
        <label for="username">Username:</label>
        <input type="text" id="username" placeholder="Enter username" required />
 
        <label for="password">Password:</label>
        <input type="password" id="password" placeholder="Enter password" required />
 
        <button type="submit">Login</button>
      </form>
 
      <p id="login-message" style="color: #b91c1c; margin-top: 1rem"></p>
    </section>
 
    <!-- HOME -->
    <section id="home" class="tab-content">
      <h2>Available Parking Slots</h2>
   
      <div id="slots-container">
        <div class="slots-column" id="motorcycle-column">
          <h3>Motorcycle Slots</h3>
          <ul id="motorcycle-list"></ul>
        </div>
 
        <div class="slots-column" id="fourwheels-column">
          <h3>Car Slots</h3>
          <ul id="fourwheels-list"></ul>
        </div>
      </div>
    </section>
 
    <!-- DASHBOARD -->
    <section id="dashboard" class="tab-content">
      <h2>User Dashboard</h2>
 
      <div class="dashboard-stats">
  <div class="stat">
    <h3 style="color:white;">Total Scans</h3>
    <p id="total-scans">5</p>
  </div>
 
  <div class="stat">
    <h3 style="color:white;">Available Slots</h3>
    <p id="available-slots">3</p>
  </div>
</div>
 
 
      <h3 style="margin-bottom: 10px;">Recent QR History</h3>
 
      <!-- ⭐ NEW CLEAR ALL BUTTON -->
      <button id="clear-history-btn" onclick="clearAllHistory()"
        style="background:#b91c1c; color:white; padding:8px 14px; border:none; border-radius:6px; cursor:pointer; margin-bottom:15px;">
        Clear All History
      </button>
 
      <!-- History List -->
      <ul id="qr-history"></ul>
    </section>
 
    <!-- GENERATE QR -->
<section id="generate" class="tab-content">
  <h2>Register</h2>
 
  <form id="qrForm" onsubmit="event.preventDefault(); generateQRCode();">
    <label for="userType">User Type:</label>
    <select id="userType" required>
      <option value="Student">Student</option>
      <option value="Visitor">Visitor</option>
      <option value="Faculty/Staff">Faculty/Staff</option>
    </select>
 
    <label for="name">Name:</label>
    <input type="text" id="name" placeholder="Enter your full name" required />
    <p id="name-error" style="color: #b91c1c; margin-top: 0.3rem; font-weight: 600; display:none;">Name must contain letters and spaces only.</p>
 
    <label for="plateNumber">Plate Number:</label>
    <input type="text" id="plateNumber" placeholder="Enter your vehicle plate number" required />
 
    <label for="vehicleType">Type of Vehicle:</label>
    <select id="vehicleType" required>
      <option value="" disabled selected>Select type of vehicle</option>
      <option value="Car">Car</option>
      <option value="Motorcycle">Motorcycle</option>
      <option value="Others">Others</option>
    </select>
 
    <button type="submit">Generate QR Code</button>
    <button type="button" onclick="printQR()">Print QR Code</button>
  </form>
 
  <div id="qrcode"></div>
</section>
 
    <!-- SCAN QR -->
    <section id="scan" class="tab-content">
      <h2>Scan QR Code at Entrance</h2>
 
      <div id="reader"></div>
 
      <!-- Show scanned info here -->
      <div id="scan-result" class="scan-result-box" style="white-space: pre-wrap; margin-top: 1rem; font-weight: 600; color: #003366;"></div>
 
      <!-- Show filtered slots in Home style -->
      <div id="scan-slots-container" style="display:none; margin-top: 2rem;">
        <div class="slots-column">
          <h3 id="scan-slot-title"></h3>
          <ul id="scan-slots-list"></ul>
        </div>
      </div>
 
      <button id="scan-btn" onclick="toggleScan()" style="margin-top: 1.5rem;">Scan</button>
    </section>
  </main>
 
  <script src="script.js"></script>
</body>
</html>
 
/* ============================================================
  COMPLETE script.js — updated scanner lifecycle + history management + Car type + Name validation
============================================================ */

let isLoggedIn = false;

/* ----------------------------
   Activity / History Storage
---------------------------- */
let qrHistory = JSON.parse(localStorage.getItem("qrActivityLog")) || [];

function saveActivityLog() {
  localStorage.setItem("qrActivityLog", JSON.stringify(qrHistory));
}

function addActivityLog(action, details) {
  const entry = { action, details, time: new Date().toLocaleString() };
  qrHistory.unshift(entry);
  saveActivityLog();
  updateDashboard();
}

/* ----------------------------
   TIME IN / TIME OUT Logic
---------------------------- */
function getIdentity(name, plateNumber) {
  return `${name.trim().toLowerCase()}_${plateNumber.trim().toLowerCase()}`;
}

function addScanLog(userType, name, plateNumber, vehicleType) {
  const last = qrHistory.find(
    l => l.details.includes(name) && l.details.includes(plateNumber)
  );

  let actionType = "TIME IN";
  if (last && last.action === "TIME IN") actionType = "TIME OUT";

  const entry = {
    action: actionType,
    details: `${userType} - ${name} (${vehicleType}) [${plateNumber}]`,
    time: new Date().toLocaleString()
  };

  qrHistory.unshift(entry);
  saveActivityLog();
  updateDashboard();
}

/* ----------------------------
   Sample slots
---------------------------- */
let motorcycleSlots = [
  "Motorcycle Slot 1 - Available",
  "Motorcycle Slot 2 - Occupied",
  "Motorcycle Slot 3 - Available",
  "Motorcycle Slot 4 - Occupied"
];

let carSlots = [
  "Car Slot 1 - Available",
  "Car Slot 2 - Occupied",
  "Car Slot 3 - Available",
  "Car Slot 4 - Occupied",
  "Car Slot 5 - Available"
];

/* ----------------------------
   Login / Nav / Tabs
---------------------------- */
function login() {
  const username = document.getElementById('username').value;
  const password = document.getElementById('password').value;

  if (username === 'admin' && password === '1234') {
    isLoggedIn = true;
    updateNav();
    showTab('home');
    setInterval(updateSlots, 30000);
  } else {
    document.getElementById('login-message').innerText = 'Invalid credentials!';
  }
}

function updateNav() {
  document.querySelectorAll('nav .tab').forEach(tab => {
    if (isLoggedIn) {
      tab.style.display = tab.dataset.tab === 'login' ? 'none' : 'block';
    } else {
      tab.style.display = tab.dataset.tab === 'login' ? 'block' : 'none';
    }
  });
}

function showTab(tab) {
  if (!isLoggedIn && tab !== 'login') return;

  document.querySelectorAll('.tab-content').forEach(sec => sec.classList.remove('active'));
  document.getElementById(tab)?.classList.add('active');

  document.querySelectorAll('nav .tab').forEach(t => t.classList.remove('active'));
  document.querySelector(`nav .tab[data-tab="${tab}"]`)?.classList.add('active');

  if (tab === 'dashboard') updateDashboard();
}

/* ----------------------------
   Slots rendering
---------------------------- */
function updateSlots() {
  motorcycleSlots = motorcycleSlots.map(toggleAvailability);
  carSlots = carSlots.map(toggleAvailability);
  renderSlots();
}

function toggleAvailability(slot) {
  return slot.includes("Available")
    ? slot.replace("Available", "Occupied")
    : slot.replace("Occupied", "Available");
}

function renderSlots() {
  const motoList = document.getElementById('motorcycle-list');
  const carList = document.getElementById('fourwheels-list');

  if (motoList) motoList.innerHTML = motorcycleSlots.map(s => `<li>${s}</li>`).join('');
  if (carList) carList.innerHTML = carSlots.map(s => `<li>${s}</li>`).join('');
}

/* ----------------------------
   Dashboard
---------------------------- */
function updateDashboard() {
  const total = document.getElementById('total-scans');
  if (total) total.innerText = qrHistory.length;

  const availableCount = motorcycleSlots.concat(carSlots).filter(s => s.includes('Available')).length;
  const availElem = document.getElementById('available-slots');
  if (availElem) availElem.innerText = availableCount;

  const historyList = document.getElementById('qr-history');
  if (historyList) {
    historyList.innerHTML = qrHistory.map((item, index) => `
      <li class="log-item">
        <strong>${item.action}:</strong> ${item.details}
        <br><span class="log-time">${item.time}</span>
        <button class="delete-btn" onclick="deleteHistoryItem(${index})">Delete</button>
      </li>
    `).join('');
  }
}

/* ============================================================
   DELETE LOG + CLEAR ALL LOGS
============================================================ */
function deleteHistoryItem(index) {
  if (!confirm("Delete this entry?")) return;

  qrHistory.splice(index, 1);
  saveActivityLog();
  updateDashboard();
}

function clearAllHistory() {
  if (!confirm("Are you sure you want to clear ALL history?")) return;

  qrHistory = [];
  saveActivityLog();
  updateDashboard();
}

/* ----------------------------
   QR Generation
---------------------------- */
function generateQRCode() {
  const userType = document.getElementById('userType').value;
  const name = document.getElementById('name').value.trim();
  const plateNumber = document.getElementById('plateNumber').value.trim();
  const vehicleType = document.getElementById('vehicleType').value;

  // Validation: Name must contain letters and spaces only
  const regex = /^[a-zA-Z\s]+$/;
  if (!regex.test(name)) {
    document.getElementById('name-error').style.display = 'block';
    alert("Please enter a valid name letters and spaces only.");
    return;
  }

  if (!userType || !name || !plateNumber || !vehicleType) {
    alert('Please fill in all required fields');
    return;
  }

  const dataObj = { userType, name, plateNumber, vehicleType };

  addActivityLog("Generated", `${userType} - ${name} (${vehicleType}) [${plateNumber}]`);

  const qrcodeContainer = document.getElementById("qrcode");
  qrcodeContainer.innerHTML = "";
  new QRCode(qrcodeContainer, { text: JSON.stringify(dataObj), width: 200, height: 200 });

  alert("QR Code generated!");
}

/* ============================================================
   Real-time Name validation: letters & spaces only
============================================================ */
const nameInput = document.getElementById('name');
const nameError = document.getElementById('name-error');

nameInput.addEventListener('input', () => {
  const regex = /^[a-zA-Z\s]*$/; // allow letters & spaces
  if (!regex.test(nameInput.value)) {
    nameError.style.display = 'block';
  } else {
    nameError.style.display = 'none';
  }
});

/* ============================================================
   SCANNER LIFECYCLE
============================================================ */
let html5Scanner = null;
let isCameraRunning = false;
let scanDebounce = false;

function setScanButtonText(text) {
  const btn = document.getElementById('scan-btn');
  if (btn) btn.innerText = text;
}

function toggleScan() {
  const scanResult = document.getElementById("scan-result");
  if (scanResult) scanResult.innerText = "";

  if (!isCameraRunning) {
    startCamera().catch(err => {
      const r = document.getElementById("scan-result");
      if (r) r.innerText = "Unable to start camera: " + (err && err.message ? err.message : err);
      setScanButtonText("Scan");
      isCameraRunning = false;
    });
  } else {
    stopCamera().catch(err => {
      const r = document.getElementById("scan-result");
      if (r) r.innerText = "Error stopping camera: " + err;
    });
  }
}

function createScannerIfNeeded() {
  if (!html5Scanner) html5Scanner = new Html5Qrcode("reader");
}

function startCamera() {
  createScannerIfNeeded();
  if (isCameraRunning) return Promise.resolve();

  setScanButtonText("Starting...");
  return html5Scanner.start(
    { facingMode: "environment" },
    { fps: 10, qrbox: 250 },
    onScanSuccess,
    onScanFailure
  ).then(() => {
    isCameraRunning = true;
    setScanButtonText("Stop Scan");
    return;
  }).catch(err => {
    isCameraRunning = false;
    throw err;
  });
}

function stopCamera() {
  if (!html5Scanner || !isCameraRunning) {
    isCameraRunning = false;
    setScanButtonText("Scan");
    return Promise.resolve();
  }

  setScanButtonText("Stopping...");
  return html5Scanner.stop().then(() => {
    isCameraRunning = false;
    setScanButtonText("Scan");
  }).catch(err => {
    isCameraRunning = false;
    setScanButtonText("Scan");
    return Promise.reject(err);
  });
}

function onScanSuccess(decodedText) {
  if (scanDebounce) return;
  scanDebounce = true;

  try {
    const data = JSON.parse(decodedText);
    const scanResult = document.getElementById("scan-result");
    if (scanResult) {
      scanResult.innerText = `User Type: ${data.userType}\nName: ${data.name}\nVehicle: ${data.vehicleType}\nPlate: ${data.plateNumber}`;
    }

    addScanLog(data.userType, data.name, data.plateNumber, data.vehicleType);

    setTimeout(() => {
      stopCamera().finally(() => setTimeout(() => scanDebounce = false, 700));
    }, 500);

  } catch (err) {
    const scanResult = document.getElementById("scan-result");
    if (scanResult) scanResult.innerText = "Invalid QR Code!";
    scanDebounce = false;
  }
}

function onScanFailure(error) {
  // silent fail
}

window.addEventListener('beforeunload', () => {
  if (html5Scanner && isCameraRunning) {
    try { html5Scanner.stop(); } catch(e) {}
  }
});

/* ----------------------------
   Show scan slots
---------------------------- */
function showScanSlots(vehicleType) {
  const container = document.getElementById('scan-slots-container');
  const slotTitle = document.getElementById('scan-slot-title');
  const slotList = document.getElementById('scan-slots-list');

  if (!container || !slotTitle || !slotList) return;
  container.style.display = 'block';

  if (vehicleType.toLowerCase() === 'motorcycle') {
    slotTitle.innerText = "Available Motorcycle Slots";
    slotList.innerHTML = motorcycleSlots.filter(s => s.includes('Available')).map(s => `<li>${s}</li>`).join('');
  } else if (vehicleType.toLowerCase() === 'car') {
    slotTitle.innerText = "Available Car Slots";
    slotList.innerHTML = carSlots.filter(s => s.includes('Available')).map(s => `<li>${s}</li>`).join('');
  } else {
    slotTitle.innerText = "Available Slots";
    slotList.innerHTML = "No specific slots available for this vehicle type.";
  }
}

function clearScanResults() {
  const container = document.getElementById('scan-slots-container');
  const slotTitle = document.getElementById('scan-slot-title');
  const slotList = document.getElementById('scan-slots-list');

  if (!container || !slotTitle || !slotList) return;
  container.style.display = 'none';
  slotTitle.innerText = "";
  slotList.innerHTML = "";
}

function resetScanButton() {
  isCameraRunning = false;
  setScanButtonText("Scan");
  const scanResult = document.getElementById('scan-result');
  if (scanResult) scanResult.innerText = "";
  clearScanResults();
}

/* ----------------------------
   Initialization
---------------------------- */
renderSlots();
updateNav();
showTab('login');

@import url('https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;700&display=swap');
 
* {
  box-sizing: border-box;
}
 
body {
  margin: 0;
  font-family: Arial, sans-serif;
  background-color: #f7f8fa;
  color: #003d99;
  display: flex;
  flex-direction: column;
  background-image: url('PIC.jpg');
  background-size: cover;
  background-repeat: no-repeat;
  background-attachment: fixed;
}
 
header {
  background-color: #003366;
  padding: 1.5rem 2rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  color: #FCE300;
  box-shadow: 0 6px 10px rgba(0, 0, 0, 0.25);
}
 
header h1 {
  margin: 0;
  font-weight: 700;
  font-size: 2rem;
  letter-spacing: 2px;
  text-transform: uppercase;
}
 
header h1 span {
  color: #FCE300;
  text-shadow: 1px 1px 2px #002244;
}
 
header img {
  height: 60px;
  border-radius: 8px;
  filter: drop-shadow(2px 2px 2px rgba(0,0,0,0.4));
}
 
nav {
  background-color: #FFFFFF;
  border-bottom: 4px solid #003366;
  display: flex;
  padding: 1rem 2rem;
  gap: 2rem;
  font-weight: 700;
  cursor: pointer;
  color: #004a99;
  text-transform: uppercase;
  letter-spacing: 1px;
  box-shadow: 0 4px 8px rgba(0,0,0,0.15);
  overflow-x: auto;
  transition: background-color 0.4s ease;
}
 
nav:hover {
  background-color: #F9F9F9;
}
 
nav .active {
  border-bottom: 6px solid #FCE300;
  color: #003366;
}
 
nav .hidden {
  display: none;
}
 
main {
  flex-grow: 1;
  padding: 3rem 3rem 4rem 3rem;
  overflow-y: auto;
  max-width: 1000px;
  margin: 0 auto;
  background-color: rgba(255, 255, 255, 0.85);
  border-radius: 20px;
  box-shadow: 0 12px 24px rgba(0,0,0,0.15);
}
 
.tab-content {
  display: none;
  max-width: 900px;
  margin: 0 auto;
  padding: 2rem 3rem;
  border-radius: 16px;
  font-weight: 500;
  letter-spacing: 0.03em;
}
 
.tab-content.active {
  display: block;
  animation: strongFadeIn 0.4s ease-in forwards;
}
 
@keyframes strongFadeIn {
  0% { opacity: 0; transform: translateY(15px); }
  100% { opacity: 1; transform: translateY(0); }
}
 
h2, h3 {
  font-weight: 700;
  color: #003366;
  margin-bottom: 1.5rem;
  letter-spacing: 1.2px;
}
 
#home h2 {
  text-align: center;
}
 
label {
  display: block;
  margin: 1.5rem 0 0.6rem 0;
  font-weight: 600;
  color: #004a99;
  text-transform: uppercase;
  letter-spacing: 0.8px;
}
 
input[type='text'],
input[type='password'],
select {
  padding: 0.85rem 1rem;
  width: 100%;
  max-width: 400px;
  border: 3px solid #003366;
  border-radius: 12px;
  font-size: 1.1rem;
  font-weight: 600;
  font-family: 'Roboto', sans-serif;
  color: #003366;
  transition: border-color 0.3s ease, box-shadow 0.4s ease;
  background: #fefefe;
}
 
input[type='text']:focus,
input[type='password']:focus,
select:focus {
  border-color: #FCE300;
  box-shadow: 0 0 10px #FCE300;
  outline: none;
  background-color: #fffdcc;
}
 
button {
  margin-top: 2rem;
  padding: 1rem 3rem;
  background-color: #004a99;
  color: #FCE300;
  border: none;
  border-radius: 14px;
  font-size: 1.25rem;
  font-weight: 700;
  cursor: pointer;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  box-shadow: 0 6px 15px rgba(0, 74, 153, 0.5);
  transition: background-color 0.4s ease, transform 0.25s ease;
  user-select: none;
}
 
button:hover {
  background-color: #003366;
  box-shadow: 0 9px 25px rgba(0, 51, 102, 0.7);
  transform: translateY(-3px);
}
 
button:active {
  transform: translateY(0);
  box-shadow: 0 4px 10px rgba(0, 74, 153, 0.4);
}
 
#qrcode {
  margin-top: 2.5rem;
  text-align: center;
  filter: drop-shadow(2px 4px 4px rgba(0, 0, 0, 0.15));
}
 
#reader {
  width: 100%;
  max-width: 440px;
  margin: 2.5rem auto;
  border: 4px solid #004a99;
  border-radius: 20px;
  box-shadow: 0 8px 20px rgba(0, 74, 153, 0.35);
  overflow: hidden;
}
 
ul#slots-list,
ul#motorcycle-list,
ul#fourwheels-list {
  list-style-type: none;
  padding-left: 0;
  margin-top: 1.75rem;
}
 
ul#slots-list li,
ul#motorcycle-list li,
ul#fourwheels-list li {
  padding: 1.3rem 1rem;
  border-bottom: 2px solid #FCE300;
  font-size: 1.25rem;
  font-weight: 600;
  color: #003366;
  background: linear-gradient(90deg, #fde047 0%, #facc15 100%);
  border-radius: 15px;
  margin-bottom: 1rem;
  box-shadow: 0 6px 12px rgba(0, 0, 0, 0.1);
  transition: background 0.35s ease, box-shadow 0.3s ease;
}
 
ul#slots-list li:hover,
ul#motorcycle-list li:hover,
ul#fourwheels-list li:hover {
  background: linear-gradient(90deg, #f59e0b 0%, #d97706 100%);
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.25);
  color: #fff;
}
 
/* Dashboard stats */
.dashboard-stats {
  display: flex;
  gap: 2.5rem;
  margin-bottom: 3rem;
  flex-wrap: wrap;
  justify-content: center;
}
 
.stat {
  background: #004a99;
  color: #FCE300;
  padding: 2.5rem 3.5rem;
  border-radius: 20px;
  text-align: center;
  flex: 1 1 200px;
  font-weight: 700;
  transition: transform 0.4s ease, box-shadow 0.4s ease;
}
 
.stat:hover {
  transform: translateY(-8px) scale(1.1);
}
 
.stat h3 {
  font-size: 1.8rem;
  margin-bottom: 0.5rem;
  letter-spacing: 1.1px;  
}
 
.stat p {
  font-size: 2.8rem;
  margin: 0;
  letter-spacing: 2px;
  text-shadow: 0 0 10px #fde047;
}
 
/* Container for the two columns in Home tab */
#slots-container {
  display: flex;
  justify-content: space-between;
  gap: 2rem;
  margin-top: 1rem;
}
 
.slots-column {
  flex: 1 1 45%;
  background-color: #fefefe;
  padding: 1rem 1.5rem;
  border-radius: 16px;
  box-shadow: 0 6px 15px rgba(0,0,0,0.1);
  min-height: 300px;
}
 
.slots-column h3 {
  margin-top: 0;
  color: #004a99;
  text-align: center;
  font-weight: 700;
  letter-spacing: 1.2px;
  border-bottom: 2px solid #FCE300;
  padding-bottom: 0.5rem;
}
 
/* Dashboard Recent QR History - stacked with bold TIME IN / TIME OUT */
#qr-history li.log-item {
  display: flex;
  flex-direction: column; /* stacked vertically */
  font-size: 1rem;        /* consistent font size */
  font-weight: 400;       /* normal weight for details */
  color: #003366;
  background-color: #ffffff;
  padding: 0.8rem 1rem;
  border-radius: 8px;
  margin-bottom: 1rem;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}
 
/* Make only TIME IN / TIME OUT bold */
#qr-history li.log-item strong {
  font-weight: 700; /* bold */
  display: inline;  /* normal inline for text */
}
 
/* Timestamp */
#qr-history li.log-item .log-time {
  font-size: 0.85rem;
  color: #002244;
  margin-top: 0.3rem;
}
 
 
/* Delete button in history */
.delete-btn {
  background-color: #d32f2f;
  color: #fff;
  border: none;
  padding: 0.45rem 0.9rem;
  border-radius: 10px;
  font-size: 0.9rem;
  cursor: pointer;
  transition: background-color 0.3s ease, transform 0.2s ease;
  margin-left: 1rem;
}
 
.delete-btn:hover {
  background-color: #9a0007;
  transform: translateY(-2px);
}
 
/* Clear all button */
#clear-history-btn {
  background-color: #f57c00;
  color: #fff;
  border: none;
  padding: 0.7rem 1.2rem;
  border-radius: 12px;
  font-weight: 700;
  font-size: 1rem;
  cursor: pointer;
  margin-bottom: 1.5rem;
  transition: background-color 0.3s ease, transform 0.2s ease;
}
 
#clear-history-btn:hover {
  background-color: #e65100;
  transform: translateY(-2px);
}
 
/* Responsive design */
@media (max-width: 768px) {
  header {
    padding: 1rem;
    flex-direction: column;
    text-align: center;
  }
  nav {
    padding: 0.75rem 1rem;
    gap: 1rem;
    justify-content: center;
  }
  nav .tab {
    font-size: 0.9rem;
  }
  main {
    padding: 2rem 1.5rem 3rem 1.5rem;
  }
  .tab-content {
    padding: 2rem 1.5rem;
  }
  .dashboard-stats {
    flex-direction: column;
    gap: 1.5rem;
  }
  ul#slots-list li,
  ul#motorcycle-list li,
  ul#fourwheels-list li {
    font-size: 1.15rem;
  }
  button {
    width: 100%;
  }
  #slots-container {
    flex-direction: column;
  }
  .slots-column {
    flex: 1 1 100%;
    margin-bottom: 2rem;
    min-height: auto;
  }
}
