import { useState } from "react";

const theme = {
  bg: "#0F1117",
  surface: "#1A1D27",
  surfaceAlt: "#22263A",
  border: "#2A2F45",
  accent: "#4FFFB0",
  accentDim: "#1A3D2E",
  accentText: "#3DD68C",
  warn: "#FF7A50",
  warnDim: "#3D1F15",
  missed: "#FF4F4F",
  missedDim: "#3D1212",
  text: "#F0F2FF",
  textMuted: "#7B80A0",
  textDim: "#4A4F6A",
  blue: "#5B8BFF",
  blueDim: "#1A2340",
};

const medications = [
  { id: 1, name: "Lisinopril", dose: "10mg", time: "8:00 AM", taken: true, takenAt: "8:04 AM", color: "#4FFFB0", type: "Heart" },
  { id: 2, name: "Metformin", dose: "500mg", time: "8:00 AM", taken: true, takenAt: "8:04 AM", color: "#5B8BFF", type: "Diabetes" },
  { id: 3, name: "Atorvastatin", dose: "20mg", time: "12:00 PM", taken: false, takenAt: null, color: "#FF7A50", type: "Cholesterol" },
  { id: 4, name: "Levothyroxine", dose: "50mcg", time: "6:00 PM", taken: false, takenAt: null, color: "#C97BFF", type: "Thyroid" },
  { id: 5, name: "Aspirin", dose: "81mg", time: "9:00 PM", taken: false, takenAt: null, color: "#FFD166", type: "Heart" },
];

const historyData = [
  { day: "Mon", date: "3", status: "perfect" },
  { day: "Tue", date: "4", status: "perfect" },
  { day: "Wed", date: "5", status: "perfect" },
  { day: "Thu", date: "6", status: "missed" },
  { day: "Fri", date: "7", status: "perfect" },
  { day: "Sat", date: "8", status: "partial" },
  { day: "Sun", date: "9", status: "perfect" },
  { day: "Mon", date: "10", status: "perfect" },
  { day: "Tue", date: "11", status: "today" },
];

const profiles = [
  { id: 1, name: "You", initials: "JD", color: "#4FFFB0", meds: 5, takenToday: 2 },
  { id: 2, name: "Mom", initials: "MD", color: "#5B8BFF", meds: 4, takenToday: 4 },
];

export default function App() {
  const [activeScreen, setActiveScreen] = useState("home");
  const [activeProfile, setActiveProfile] = useState(0);
  const [meds, setMeds] = useState(medications);
  const [justTaken, setJustTaken] = useState(null);
  const [showAddMed, setShowAddMed] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [allDoneAnim, setAllDoneAnim] = useState(false);

  const markTaken = (id) => {
    setJustTaken(id);
    setTimeout(() => {
      setMeds(prev => prev.map(m => m.id === id ? { ...m, taken: true, takenAt: "now" } : m));
      setJustTaken(null);
    }, 600);
  };

  const markAllTaken = () => {
    setShowConfirm(false);
    setAllDoneAnim(true);
    setMeds(prev => prev.map(m => ({ ...m, taken: true, takenAt: "now" })));
    setTimeout(() => setAllDoneAnim(false), 2000);
  };

  const pending = meds.filter(m => !m.taken);
  const taken = meds.filter(m => m.taken);

  return (
    <div style={{
      minHeight: "100vh",
      background: "#070A12",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontFamily: "'DM Sans', sans-serif",
      padding: "24px 16px",
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::-webkit-scrollbar { width: 0; }
        .pill-btn { transition: all 0.18s ease; cursor: pointer; border: none; outline: none; }
        .pill-btn:active { transform: scale(0.96); }
        .tab-item { transition: all 0.2s ease; cursor: pointer; }
        .tab-item:hover { opacity: 0.85; }
        .med-card { transition: all 0.3s ease; }
        .med-card:hover { transform: translateY(-1px); }
        .take-btn { transition: all 0.2s ease; cursor: pointer; border: none; outline: none; }
        .take-btn:hover { filter: brightness(1.1); }
        .take-btn:active { transform: scale(0.93); }
        @keyframes checkPop {
          0% { transform: scale(0.5); opacity: 0; }
          60% { transform: scale(1.2); }
          100% { transform: scale(1); opacity: 1; }
        }
        @keyframes slideUp {
          from { opacity: 0; transform: translateY(12px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .slide-up { animation: slideUp 0.35s ease forwards; }
        .check-pop { animation: checkPop 0.4s ease forwards; }
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
        .pulse { animation: pulse 2s ease infinite; }
        @keyframes floatIn {
          from { opacity: 0; transform: translateY(20px) translateX(-50%); }
          to { opacity: 1; transform: translateY(0) translateX(-50%); }
        }
        @keyframes fadeIn {
          from { opacity: 0; }
          to { opacity: 1; }
        }
        @keyframes modalUp {
          from { opacity: 0; transform: translateY(30px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .float-in { animation: floatIn 0.3s ease forwards; }
        .fade-in { animation: fadeIn 0.2s ease forwards; }
        .modal-up { animation: modalUp 0.25s ease forwards; }
        @keyframes allDone {
          0% { transform: scale(1) translateX(-50%); }
          40% { transform: scale(1.06) translateX(-47%); }
          100% { transform: scale(1) translateX(-50%); }
        }
        .all-done { animation: allDone 0.4s ease forwards; }
      `}</style>

      {/* Phone Frame */}
      <div style={{
        width: 390,
        minHeight: 844,
        background: theme.bg,
        borderRadius: 52,
        overflow: "hidden",
        boxShadow: "0 40px 120px rgba(0,0,0,0.8), 0 0 0 1px rgba(255,255,255,0.06), inset 0 0 0 1px rgba(255,255,255,0.03)",
        position: "relative",
        display: "flex",
        flexDirection: "column",
      }}>

        {/* Status Bar */}
        <div style={{ padding: "16px 28px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ color: theme.text, fontSize: 15, fontWeight: 600, fontFamily: "'DM Mono', monospace" }}>9:41</span>
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            {[3,3,3].map((_, i) => (
              <div key={i} style={{ width: 6, height: 6, borderRadius: 3, background: i < 2 ? theme.text : theme.textDim }} />
            ))}
            <div style={{ width: 22, height: 11, borderRadius: 3, border: `1.5px solid ${theme.textMuted}`, position: "relative", marginLeft: 2 }}>
              <div style={{ position: "absolute", left: 2, top: 2, bottom: 2, width: "70%", background: theme.accent, borderRadius: 1.5 }} />
            </div>
          </div>
        </div>

        {/* Screen Content */}
        <div style={{ flex: 1, overflowY: "auto", paddingBottom: 90 }}>
          {activeScreen === "home" && <HomeScreen meds={meds} taken={taken} pending={pending} markTaken={markTaken} justTaken={justTaken} activeProfile={activeProfile} setActiveProfile={setActiveProfile} />}
          {activeScreen === "history" && <HistoryScreen meds={meds} />}
          {activeScreen === "meds" && <MedsScreen meds={meds} showAdd={showAddMed} setShowAdd={setShowAddMed} />}
          {activeScreen === "settings" && <SettingsScreen />}
        </div>

        {/* Floating Mark All Button — only on home screen with pending meds */}
        {activeScreen === "home" && pending.length > 0 && (
          <div
            className={allDoneAnim ? "all-done" : "float-in"}
            onClick={() => setShowConfirm(true)}
            style={{
              position: "absolute",
              bottom: 100,
              left: "50%",
              transform: "translateX(-50%)",
              background: `linear-gradient(135deg, ${theme.accent}, #2BDEAA)`,
              borderRadius: 28,
              padding: "14px 28px",
              display: "flex", alignItems: "center", gap: 10,
              cursor: "pointer",
              boxShadow: `0 8px 32px ${theme.accent}40, 0 2px 8px rgba(0,0,0,0.4)`,
              whiteSpace: "nowrap",
              zIndex: 10,
            }}
          >
            <span style={{ fontSize: 16 }}>✓</span>
            <span style={{ color: "#0A1A12", fontSize: 14, fontWeight: 700, letterSpacing: "0.1px" }}>
              Mark All Taken
            </span>
            <span style={{
              background: "rgba(0,0,0,0.15)",
              borderRadius: 10,
              padding: "2px 8px",
              color: "#0A1A12",
              fontSize: 12,
              fontWeight: 700,
            }}>{pending.length}</span>
          </div>
        )}

        {/* All done celebration */}
        {activeScreen === "home" && pending.length === 0 && allDoneAnim && (
          <div className="float-in" style={{
            position: "absolute", bottom: 100, left: "50%", transform: "translateX(-50%)",
            background: theme.accentDim, border: `1px solid ${theme.accent}40`,
            borderRadius: 28, padding: "14px 28px",
            display: "flex", alignItems: "center", gap: 8,
            whiteSpace: "nowrap", zIndex: 10,
          }}>
            <span style={{ fontSize: 16 }}>🎉</span>
            <span style={{ color: theme.accent, fontSize: 14, fontWeight: 700 }}>All done for today!</span>
          </div>
        )}

        {/* Confirmation Modal */}
        {showConfirm && (
          <div className="fade-in" style={{
            position: "absolute", inset: 0,
            background: "rgba(7,10,18,0.85)",
            backdropFilter: "blur(8px)",
            display: "flex", alignItems: "flex-end",
            zIndex: 20, borderRadius: 52,
          }}>
            <div className="modal-up" style={{
              width: "100%",
              background: theme.surface,
              borderTop: `1px solid ${theme.border}`,
              borderRadius: "32px 32px 0 0",
              padding: "28px 24px 48px",
            }}>
              {/* Handle bar */}
              <div style={{ width: 36, height: 4, borderRadius: 2, background: theme.border, margin: "0 auto 24px" }} />

              <div style={{ textAlign: "center", marginBottom: 28 }}>
                <div style={{
                  width: 56, height: 56, borderRadius: 28,
                  background: theme.accentDim,
                  border: `2px solid ${theme.accent}40`,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  margin: "0 auto 16px",
                }}>
                  <span style={{ fontSize: 24 }}>💊</span>
                </div>
                <h2 style={{ color: theme.text, fontSize: 20, fontWeight: 700, marginBottom: 8 }}>
                  Mark all as taken?
                </h2>
                <p style={{ color: theme.textMuted, fontSize: 14, lineHeight: 1.5 }}>
                  This will mark all {pending.length} remaining{"\n"}medication{pending.length !== 1 ? "s" : ""} as taken right now.
                </p>
              </div>

              {/* Pending med pills preview */}
              <div style={{ display: "flex", flexWrap: "wrap", gap: 8, justifyContent: "center", marginBottom: 28 }}>
                {pending.map(med => (
                  <div key={med.id} style={{
                    background: `${med.color}15`,
                    border: `1px solid ${med.color}40`,
                    borderRadius: 20,
                    padding: "6px 14px",
                    display: "flex", alignItems: "center", gap: 6,
                  }}>
                    <div style={{ width: 6, height: 6, borderRadius: 3, background: med.color }} />
                    <span style={{ color: theme.text, fontSize: 13, fontWeight: 500 }}>{med.name}</span>
                  </div>
                ))}
              </div>

              {/* Buttons */}
              <button className="pill-btn" onClick={markAllTaken} style={{
                width: "100%", background: theme.accent, border: "none",
                borderRadius: 16, padding: "16px",
                color: "#0A1A12", fontSize: 16, fontWeight: 700,
                cursor: "pointer", marginBottom: 12,
              }}>
                Yes, mark all taken
              </button>
              <button className="pill-btn" onClick={() => setShowConfirm(false)} style={{
                width: "100%", background: "transparent",
                border: `1px solid ${theme.border}`,
                borderRadius: 16, padding: "16px",
                color: theme.textMuted, fontSize: 15, fontWeight: 500,
                cursor: "pointer",
              }}>
                Cancel
              </button>
            </div>
          </div>
        )}

        {/* Bottom Nav */}
        <div style={{
          position: "absolute", bottom: 0, left: 0, right: 0,
          background: "rgba(15,17,23,0.95)",
          backdropFilter: "blur(20px)",
          borderTop: `1px solid ${theme.border}`,
          padding: "12px 0 28px",
          display: "flex", justifyContent: "space-around", alignItems: "center",
        }}>
          {[
            { id: "home", icon: HomeIcon, label: "Today" },
            { id: "history", icon: CalIcon, label: "History" },
            { id: "meds", icon: PillIcon, label: "Meds" },
            { id: "settings", icon: GearIcon, label: "Settings" },
          ].map(({ id, icon: Icon, label }) => (
            <div key={id} className="tab-item" onClick={() => setActiveScreen(id)}
              style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4, minWidth: 60 }}>
              <div style={{
                width: 44, height: 28, borderRadius: 14,
                background: activeScreen === id ? theme.accentDim : "transparent",
                display: "flex", alignItems: "center", justifyContent: "center",
                transition: "all 0.2s ease",
              }}>
                <Icon color={activeScreen === id ? theme.accent : theme.textDim} />
              </div>
              <span style={{
                fontSize: 11, fontWeight: 500,
                color: activeScreen === id ? theme.accent : theme.textDim,
                transition: "color 0.2s ease",
              }}>{label}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function HomeScreen({ meds, taken, pending, markTaken, justTaken, activeProfile, setActiveProfile }) {
  const progress = taken.length / meds.length;

  return (
    <div style={{ padding: "20px 24px 0" }} className="slide-up">
      {/* Profile Switcher */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <div>
          <p style={{ color: theme.textMuted, fontSize: 13, fontWeight: 500, marginBottom: 3 }}>Good morning</p>
          <h1 style={{ color: theme.text, fontSize: 26, fontWeight: 700, letterSpacing: "-0.5px" }}>
            {profiles[activeProfile].name === "You" ? "Your Meds" : `${profiles[activeProfile].name}'s Meds`}
          </h1>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          {profiles.map((p, i) => (
            <div key={p.id} onClick={() => setActiveProfile(i)} className="pill-btn"
              style={{
                width: 38, height: 38, borderRadius: 19,
                background: activeProfile === i ? p.color : theme.surface,
                border: `2px solid ${activeProfile === i ? p.color : theme.border}`,
                display: "flex", alignItems: "center", justifyContent: "center",
                cursor: "pointer",
              }}>
              <span style={{ fontSize: 13, fontWeight: 700, color: activeProfile === i ? "#0F1117" : theme.textMuted }}>
                {p.initials}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Progress Card */}
      <div style={{
        background: theme.surface,
        borderRadius: 20,
        padding: "20px 22px",
        border: `1px solid ${theme.border}`,
        marginBottom: 28,
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 16 }}>
          <div>
            <p style={{ color: theme.textMuted, fontSize: 12, fontWeight: 500, textTransform: "uppercase", letterSpacing: "0.8px", marginBottom: 6 }}>Today's Progress</p>
            <p style={{ color: theme.text, fontSize: 32, fontWeight: 700, letterSpacing: "-1px" }}>
              {taken.length}<span style={{ color: theme.textMuted, fontSize: 18, fontWeight: 400 }}>/{meds.length}</span>
            </p>
          </div>
          <div style={{
            background: taken.length === meds.length ? theme.accentDim : theme.surfaceAlt,
            borderRadius: 12,
            padding: "6px 12px",
          }}>
            <span style={{ color: taken.length === meds.length ? theme.accent : theme.textMuted, fontSize: 12, fontWeight: 600 }}>
              {taken.length === meds.length ? "✓ Complete" : `${pending.length} pending`}
            </span>
          </div>
        </div>
        {/* Progress Bar */}
        <div style={{ height: 6, background: theme.surfaceAlt, borderRadius: 3, overflow: "hidden" }}>
          <div style={{
            height: "100%", borderRadius: 3,
            background: `linear-gradient(90deg, ${theme.accent}, ${theme.blue})`,
            width: `${progress * 100}%`,
            transition: "width 0.6s ease",
          }} />
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 10 }}>
          <span style={{ color: theme.textMuted, fontSize: 11 }}>🔥 7 day streak</span>
          <span style={{ color: theme.accentText, fontSize: 11, fontWeight: 600 }}>{Math.round(progress * 100)}% done</span>
        </div>
      </div>

      {/* Pending Meds */}
      {pending.length > 0 && (
        <div style={{ marginBottom: 24 }}>
          <p style={{ color: theme.textMuted, fontSize: 12, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.8px", marginBottom: 14 }}>Upcoming</p>
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {pending.map(med => (
              <MedCard key={med.id} med={med} markTaken={markTaken} justTaken={justTaken} />
            ))}
          </div>
        </div>
      )}

      {/* Taken Meds */}
      {taken.length > 0 && (
        <div>
          <p style={{ color: theme.textMuted, fontSize: 12, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.8px", marginBottom: 14 }}>Taken</p>
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {taken.map(med => (
              <MedCard key={med.id} med={med} markTaken={markTaken} justTaken={justTaken} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function MedCard({ med, markTaken, justTaken }) {
  const isTaking = justTaken === med.id;

  return (
    <div className="med-card" style={{
      background: med.taken ? "rgba(26,29,39,0.5)" : theme.surface,
      borderRadius: 16,
      padding: "14px 16px",
      border: `1px solid ${med.taken ? theme.border : theme.border}`,
      display: "flex", alignItems: "center", gap: 14,
      opacity: med.taken ? 0.6 : 1,
    }}>
      {/* Color dot */}
      <div style={{
        width: 40, height: 40, borderRadius: 12,
        background: med.taken ? theme.surfaceAlt : `${med.color}18`,
        border: `1.5px solid ${med.taken ? theme.border : med.color}40`,
        display: "flex", alignItems: "center", justifyContent: "center",
        flexShrink: 0,
      }}>
        <div style={{
          width: 10, height: 10, borderRadius: 5,
          background: med.taken ? theme.textDim : med.color,
        }} />
      </div>

      {/* Info */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{
          color: med.taken ? theme.textMuted : theme.text,
          fontSize: 15, fontWeight: 600, marginBottom: 3,
          textDecoration: med.taken ? "line-through" : "none",
        }}>{med.name}</p>
        <p style={{ color: theme.textDim, fontSize: 12 }}>
          {med.dose} · {med.taken ? `Taken at ${med.takenAt}` : med.time}
        </p>
      </div>

      {/* Action */}
      {!med.taken ? (
        <button className="take-btn" onClick={() => markTaken(med.id)} style={{
          background: isTaking ? theme.accentDim : theme.accentDim,
          border: `1.5px solid ${theme.accent}50`,
          borderRadius: 12, padding: "8px 16px",
          color: theme.accent, fontSize: 13, fontWeight: 600,
        }}>
          {isTaking ? "✓" : "Take"}
        </button>
      ) : (
        <div className="check-pop" style={{
          width: 28, height: 28, borderRadius: 14,
          background: theme.accentDim,
          display: "flex", alignItems: "center", justifyContent: "center",
        }}>
          <span style={{ color: theme.accent, fontSize: 14 }}>✓</span>
        </div>
      )}
    </div>
  );
}

function HistoryScreen() {
  const [selectedDay, setSelectedDay] = useState(null);

  return (
    <div style={{ padding: "20px 24px 0" }} className="slide-up">
      <h1 style={{ color: theme.text, fontSize: 26, fontWeight: 700, letterSpacing: "-0.5px", marginBottom: 6 }}>History</h1>
      <p style={{ color: theme.textMuted, fontSize: 14, marginBottom: 28 }}>March 2026</p>

      {/* Week Strip */}
      <div style={{
        background: theme.surface, borderRadius: 20, padding: "18px 16px",
        border: `1px solid ${theme.border}`, marginBottom: 24,
      }}>
        <p style={{ color: theme.textMuted, fontSize: 11, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.8px", marginBottom: 14 }}>This Week</p>
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          {historyData.slice(-7).map((d, i) => {
            const colors = {
              perfect: theme.accent,
              partial: "#FFD166",
              missed: theme.missed,
              today: theme.blue,
            };
            return (
              <div key={i} onClick={() => setSelectedDay(selectedDay === i ? null : i)}
                style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8, cursor: "pointer" }}>
                <span style={{ color: theme.textDim, fontSize: 11, fontWeight: 500 }}>{d.day}</span>
                <div style={{
                  width: 32, height: 32, borderRadius: 10,
                  background: selectedDay === i ? colors[d.status] : `${colors[d.status]}25`,
                  border: `2px solid ${selectedDay === i ? colors[d.status] : colors[d.status]}50`,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  transition: "all 0.2s ease",
                }}>
                  {d.status === "today" && <div className="pulse" style={{ width: 8, height: 8, borderRadius: 4, background: theme.blue }} />}
                  {d.status === "perfect" && <span style={{ fontSize: 12, color: selectedDay === i ? "#0F1117" : theme.accent }}>✓</span>}
                  {d.status === "missed" && <span style={{ fontSize: 12, color: selectedDay === i ? "#fff" : theme.missed }}>✕</span>}
                  {d.status === "partial" && <span style={{ fontSize: 12, color: selectedDay === i ? "#0F1117" : "#FFD166" }}>~</span>}
                </div>
                <span style={{ color: theme.textDim, fontSize: 11 }}>{d.date}</span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Stats */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginBottom: 24 }}>
        {[
          { label: "This Month", value: "92%", sub: "adherence rate", color: theme.accent },
          { label: "Streak", value: "7", sub: "days in a row", color: theme.blue },
          { label: "Best Streak", value: "21", sub: "days", color: "#FFD166" },
          { label: "Missed", value: "2", sub: "this month", color: theme.missed },
        ].map((stat, i) => (
          <div key={i} style={{
            background: theme.surface, borderRadius: 16, padding: "16px",
            border: `1px solid ${theme.border}`,
          }}>
            <p style={{ color: theme.textMuted, fontSize: 11, fontWeight: 500, marginBottom: 8 }}>{stat.label}</p>
            <p style={{ color: stat.color, fontSize: 28, fontWeight: 700, letterSpacing: "-1px", marginBottom: 2 }}>{stat.value}</p>
            <p style={{ color: theme.textDim, fontSize: 11 }}>{stat.sub}</p>
          </div>
        ))}
      </div>

      {/* Recent log */}
      <p style={{ color: theme.textMuted, fontSize: 12, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.8px", marginBottom: 14 }}>Today's Log</p>
      {medications.map(med => (
        <div key={med.id} style={{
          display: "flex", alignItems: "center", gap: 12,
          padding: "12px 0",
          borderBottom: `1px solid ${theme.border}`,
        }}>
          <div style={{ width: 8, height: 8, borderRadius: 4, background: med.taken ? theme.accent : theme.textDim, flexShrink: 0 }} />
          <span style={{ flex: 1, color: med.taken ? theme.text : theme.textMuted, fontSize: 14, fontWeight: 500 }}>{med.name} {med.dose}</span>
          <span style={{ color: med.taken ? theme.accentText : theme.textDim, fontSize: 12, fontFamily: "'DM Mono', monospace" }}>
            {med.taken ? med.takenAt : med.time}
          </span>
        </div>
      ))}
    </div>
  );
}

function MedsScreen({ showAdd, setShowAdd }) {
  const [newMed, setNewMed] = useState({ name: "", dose: "", time: "08:00" });

  return (
    <div style={{ padding: "20px 24px 0" }} className="slide-up">
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <div>
          <h1 style={{ color: theme.text, fontSize: 26, fontWeight: 700, letterSpacing: "-0.5px" }}>My Meds</h1>
          <p style={{ color: theme.textMuted, fontSize: 13, marginTop: 3 }}>{medications.length} medications</p>
        </div>
        <button className="pill-btn" onClick={() => setShowAdd(!showAdd)} style={{
          background: showAdd ? theme.surface : theme.accentDim,
          border: `1.5px solid ${showAdd ? theme.border : theme.accent}50`,
          borderRadius: 14, padding: "10px 18px",
          color: showAdd ? theme.textMuted : theme.accent,
          fontSize: 14, fontWeight: 600, cursor: "pointer",
        }}>
          {showAdd ? "Cancel" : "+ Add"}
        </button>
      </div>

      {/* Add Med Form */}
      {showAdd && (
        <div className="slide-up" style={{
          background: theme.surface, borderRadius: 20, padding: 20,
          border: `1px solid ${theme.accent}30`, marginBottom: 20,
        }}>
          <p style={{ color: theme.accent, fontSize: 13, fontWeight: 600, marginBottom: 16 }}>New Medication</p>
          {[
            { label: "Medication name", key: "name", placeholder: "e.g. Lisinopril", type: "text" },
            { label: "Dose", key: "dose", placeholder: "e.g. 10mg", type: "text" },
            { label: "Time", key: "time", placeholder: "", type: "time" },
          ].map(field => (
            <div key={field.key} style={{ marginBottom: 14 }}>
              <p style={{ color: theme.textMuted, fontSize: 12, fontWeight: 500, marginBottom: 6 }}>{field.label}</p>
              <input
                type={field.type}
                placeholder={field.placeholder}
                value={newMed[field.key]}
                onChange={e => setNewMed(prev => ({ ...prev, [field.key]: e.target.value }))}
                style={{
                  width: "100%", background: theme.surfaceAlt, border: `1px solid ${theme.border}`,
                  borderRadius: 12, padding: "12px 14px", color: theme.text,
                  fontSize: 14, outline: "none", fontFamily: "'DM Sans', sans-serif",
                  colorScheme: "dark",
                }}
              />
            </div>
          ))}
          <button className="pill-btn" style={{
            width: "100%", background: theme.accent, border: "none",
            borderRadius: 14, padding: "14px", color: "#0F1117",
            fontSize: 15, fontWeight: 700, cursor: "pointer", marginTop: 4,
          }}>
            Save Medication
          </button>
        </div>
      )}

      {/* Med List */}
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {medications.map(med => (
          <div key={med.id} style={{
            background: theme.surface, borderRadius: 16, padding: "16px",
            border: `1px solid ${theme.border}`,
            display: "flex", alignItems: "center", gap: 14,
          }}>
            <div style={{
              width: 44, height: 44, borderRadius: 13,
              background: `${med.color}15`,
              border: `2px solid ${med.color}40`,
              display: "flex", alignItems: "center", justifyContent: "center",
              flexShrink: 0,
            }}>
              <div style={{ width: 12, height: 12, borderRadius: 6, background: med.color }} />
            </div>
            <div style={{ flex: 1 }}>
              <p style={{ color: theme.text, fontSize: 15, fontWeight: 600, marginBottom: 3 }}>{med.name}</p>
              <p style={{ color: theme.textDim, fontSize: 12 }}>{med.dose} · {med.type} · {med.time}</p>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
              <button className="pill-btn" style={{
                background: "transparent", border: `1px solid ${theme.border}`,
                borderRadius: 8, padding: "5px 10px",
                color: theme.textMuted, fontSize: 11, fontWeight: 500, cursor: "pointer",
              }}>Edit</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function SettingsScreen() {
  const [notifications, setNotifications] = useState(true);
  const [criticalAlerts, setCriticalAlerts] = useState(true);
  const [snooze, setSnooze] = useState(false);

  const Toggle = ({ val, onToggle }) => (
    <div onClick={onToggle} style={{
      width: 44, height: 26, borderRadius: 13,
      background: val ? theme.accent : theme.surfaceAlt,
      border: `1px solid ${val ? theme.accent : theme.border}`,
      position: "relative", cursor: "pointer", transition: "all 0.2s ease",
    }}>
      <div style={{
        position: "absolute", top: 3, left: val ? 21 : 3,
        width: 18, height: 18, borderRadius: 9,
        background: val ? "#0F1117" : theme.textDim,
        transition: "left 0.2s ease",
      }} />
    </div>
  );

  return (
    <div style={{ padding: "20px 24px 0" }} className="slide-up">
      <h1 style={{ color: theme.text, fontSize: 26, fontWeight: 700, letterSpacing: "-0.5px", marginBottom: 28 }}>Settings</h1>

      {/* Profile */}
      <div style={{ background: theme.surface, borderRadius: 20, padding: 20, border: `1px solid ${theme.border}`, marginBottom: 16 }}>
        <p style={{ color: theme.textMuted, fontSize: 11, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.8px", marginBottom: 16 }}>Profile</p>
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <div style={{ width: 50, height: 50, borderRadius: 25, background: `${theme.accent}20`, border: `2px solid ${theme.accent}40`, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <span style={{ color: theme.accent, fontWeight: 700, fontSize: 16 }}>JD</span>
          </div>
          <div>
            <p style={{ color: theme.text, fontWeight: 600, marginBottom: 2 }}>John Doe</p>
            <p style={{ color: theme.textMuted, fontSize: 12 }}>Personal profile</p>
          </div>
        </div>
      </div>

      {/* Notifications */}
      <div style={{ background: theme.surface, borderRadius: 20, padding: 20, border: `1px solid ${theme.border}`, marginBottom: 16 }}>
        <p style={{ color: theme.textMuted, fontSize: 11, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.8px", marginBottom: 16 }}>Notifications</p>
        {[
          { label: "Reminders", sub: "Get notified when it's time", val: notifications, fn: () => setNotifications(v => !v) },
          { label: "Critical Alerts", sub: "Sound even on silent", val: criticalAlerts, fn: () => setCriticalAlerts(v => !v) },
          { label: "Snooze", sub: "Remind again after 10 min", val: snooze, fn: () => setSnooze(v => !v) },
        ].map((item, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", paddingBottom: i < 2 ? 16 : 0, marginBottom: i < 2 ? 16 : 0, borderBottom: i < 2 ? `1px solid ${theme.border}` : "none" }}>
            <div>
              <p style={{ color: theme.text, fontSize: 14, fontWeight: 500, marginBottom: 2 }}>{item.label}</p>
              <p style={{ color: theme.textDim, fontSize: 11 }}>{item.sub}</p>
            </div>
            <Toggle val={item.val} onToggle={item.fn} />
          </div>
        ))}
      </div>

      {/* Profiles */}
      <div style={{ background: theme.surface, borderRadius: 20, padding: 20, border: `1px solid ${theme.border}`, marginBottom: 16 }}>
        <p style={{ color: theme.textMuted, fontSize: 11, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.8px", marginBottom: 16 }}>Profiles</p>
        {profiles.map(p => (
          <div key={p.id} style={{ display: "flex", alignItems: "center", gap: 12, paddingBottom: 14, marginBottom: 14, borderBottom: `1px solid ${theme.border}` }}>
            <div style={{ width: 36, height: 36, borderRadius: 18, background: `${p.color}20`, border: `2px solid ${p.color}40`, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <span style={{ color: p.color, fontWeight: 700, fontSize: 12 }}>{p.initials}</span>
            </div>
            <div style={{ flex: 1 }}>
              <p style={{ color: theme.text, fontSize: 14, fontWeight: 500 }}>{p.name}</p>
              <p style={{ color: theme.textDim, fontSize: 11 }}>{p.meds} medications</p>
            </div>
            <span style={{ color: theme.textMuted, fontSize: 12 }}>Edit</span>
          </div>
        ))}
        <button className="pill-btn" style={{
          width: "100%", background: "transparent", border: `1.5px dashed ${theme.border}`,
          borderRadius: 12, padding: "12px", color: theme.textMuted,
          fontSize: 13, fontWeight: 500, cursor: "pointer",
        }}>+ Add Profile</button>
      </div>

      <div style={{ padding: "8px 0", textAlign: "center" }}>
        <p style={{ color: theme.textDim, fontSize: 12 }}>MedTrack v1.0 · Free Plan</p>
      </div>
    </div>
  );
}

// Icons
const HomeIcon = ({ color }) => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
    <path d="M3 9.5L12 3L21 9.5V20C21 20.55 20.55 21 20 21H15V15H9V21H4C3.45 21 3 20.55 3 20V9.5Z" fill={color} />
  </svg>
);
const CalIcon = ({ color }) => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
    <rect x="3" y="4" width="18" height="18" rx="3" stroke={color} strokeWidth="2" fill="none"/>
    <path d="M3 9H21" stroke={color} strokeWidth="2"/>
    <path d="M8 2V6M16 2V6" stroke={color} strokeWidth="2" strokeLinecap="round"/>
    <rect x="7" y="13" width="3" height="3" rx="1" fill={color}/>
    <rect x="14" y="13" width="3" height="3" rx="1" fill={color}/>
  </svg>
);
const PillIcon = ({ color }) => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
    <path d="M10.5 3.5C8 3.5 6 5.5 6 8V16C6 18.5 8 20.5 10.5 20.5C13 20.5 15 18.5 15 16V8C15 5.5 13 3.5 10.5 3.5Z" stroke={color} strokeWidth="2" fill="none"/>
    <path d="M6 12H15" stroke={color} strokeWidth="2"/>
    <path d="M18 8L20 10M20 8L18 10" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </svg>
);
const GearIcon = ({ color }) => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="3" stroke={color} strokeWidth="2"/>
    <path d="M12 2V4M12 20V22M4.22 4.22L5.64 5.64M18.36 18.36L19.78 19.78M2 12H4M20 12H22M4.22 19.78L5.64 18.36M18.36 5.64L19.78 4.22" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </svg>
);
