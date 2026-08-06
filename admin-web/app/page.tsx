"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

type Quest = {
  id: number;
  title: string;
  description?: string | null;
  grade: "NORMAL" | "RARE" | "EPIC" | "LEGENDARY";
  cadence: "DAILY" | "WEEKLY";
  completionType: "SELF_REPORT" | "LOCATION";
  expReward: number;
  placeName?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  radiusM?: number | null;
  active: boolean;
};

type Draft = Omit<Quest, "id">;

const emptyDraft: Draft = {
  title: "",
  description: "",
  grade: "NORMAL",
  cadence: "DAILY",
  completionType: "SELF_REPORT",
  expReward: 10,
  active: true,
  placeName: "",
  latitude: null,
  longitude: null,
  radiusM: 100,
};

const apiBase = "/api/backend";

async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = typeof window === "undefined" ? null : sessionStorage.getItem("lq-admin-token");
  const response = await fetch(`${apiBase}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  });
  const body = await response.json().catch(() => null);
  if (!response.ok || body?.success === false) {
    throw new Error(body?.error?.message || `요청에 실패했습니다 (${response.status})`);
  }
  return (body?.data ?? body) as T;
}

export default function Home() {
  const [token, setToken] = useState<string | null>(null);
  const [quests, setQuests] = useState<Quest[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<"ALL" | "ACTIVE" | "INACTIVE">("ALL");
  const [editing, setEditing] = useState<Quest | null | "new">(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const page = await api<{ content: Quest[] }>("/admin/quests?page=0&size=100");
      setQuests(page.content);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "목록을 불러오지 못했습니다");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const saved = sessionStorage.getItem("lq-admin-token");
    if (saved) setToken(saved);
  }, []);

  useEffect(() => {
    if (token) void load();
  }, [token, load]);

  const visible = useMemo(() => quests.filter((quest) => {
    const matchesQuery = `${quest.title} ${quest.description || ""}`.toLowerCase().includes(query.toLowerCase());
    const matchesFilter = filter === "ALL" || (filter === "ACTIVE" ? quest.active : !quest.active);
    return matchesQuery && matchesFilter;
  }), [quests, query, filter]);

  if (!token) return <Login onSuccess={(next) => { sessionStorage.setItem("lq-admin-token", next); setToken(next); }} />;

  return (
    <main className="shell">
      <aside className="sidebar">
        <div className="brand"><span className="brandMark">LQ</span><div><strong>LifeQuest</strong><small>ADMIN CONSOLE</small></div></div>
        <nav aria-label="관리 메뉴">
          <button className="navItem active"><span>◆</span> 퀘스트 관리</button>
          <button className="navItem" disabled><span>◇</span> 레벨 보상 <em>준비 중</em></button>
        </nav>
        <button className="logout" onClick={() => { sessionStorage.removeItem("lq-admin-token"); setToken(null); }}>로그아웃</button>
      </aside>

      <section className="content">
        <header className="topbar">
          <div><p className="eyebrow">QUEST OPERATIONS</p><h1>퀘스트 관리</h1><p>모험가에게 배정할 퀘스트를 등록하고 운영 상태를 관리합니다.</p></div>
          <button className="primary" onClick={() => setEditing("new")}><span>＋</span> 새 퀘스트</button>
        </header>

        <div className="stats">
          <Stat label="전체 퀘스트" value={quests.length} tone="ink" />
          <Stat label="활성" value={quests.filter((q) => q.active).length} tone="green" />
          <Stat label="비활성" value={quests.filter((q) => !q.active).length} tone="sand" />
        </div>

        <section className="panel">
          <div className="toolbar">
            <label className="search"><span>⌕</span><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="퀘스트 이름 검색" /></label>
            <div className="segments" aria-label="상태 필터">
              {(["ALL", "ACTIVE", "INACTIVE"] as const).map((value) => <button key={value} className={filter === value ? "selected" : ""} onClick={() => setFilter(value)}>{value === "ALL" ? "전체" : value === "ACTIVE" ? "활성" : "비활성"}</button>)}
            </div>
          </div>

          {error && <div className="errorBanner"><span>{error}</span><button onClick={() => void load()}>다시 시도</button></div>}
          {loading ? <div className="empty">퀘스트를 불러오는 중입니다…</div> : visible.length === 0 ? <div className="empty">조건에 맞는 퀘스트가 없습니다.</div> : (
            <div className="tableWrap"><table><thead><tr><th>퀘스트</th><th>등급</th><th>주기</th><th>인증</th><th>보상</th><th>상태</th><th><span className="srOnly">작업</span></th></tr></thead>
              <tbody>{visible.map((quest) => <tr key={quest.id}><td><strong>{quest.title}</strong><small>{quest.description || "설명 없음"}</small></td><td><Badge value={quest.grade} /></td><td>{quest.cadence}</td><td>{quest.completionType === "LOCATION" ? `GPS · ${quest.placeName || "장소"}` : "직접 완료"}</td><td><b>{quest.expReward} EXP</b></td><td><span className={`status ${quest.active ? "on" : "off"}`}>{quest.active ? "활성" : "비활성"}</span></td><td><button className="edit" onClick={() => setEditing(quest)}>수정</button></td></tr>)}</tbody>
            </table></div>
          )}
        </section>
      </section>

      {editing && <QuestModal quest={editing === "new" ? null : editing} onClose={() => setEditing(null)} onSaved={async () => { setEditing(null); await load(); }} />}
    </main>
  );
}

function Login({ onSuccess }: { onSuccess: (token: string) => void }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function submit(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError("");
    try {
      const result = await api<{ accessToken: string }>("/auth/login", { method: "POST", body: JSON.stringify({ email, password }) });
      onSuccess(result.accessToken);
    } catch (reason) { setError(reason instanceof Error ? reason.message : "로그인에 실패했습니다"); }
    finally { setBusy(false); }
  }
  return <main className="loginPage"><section className="loginCard"><div className="loginArt"><span className="brandMark large">LQ</span><p>작은 퀘스트가<br />큰 모험을 만듭니다.</p></div><form onSubmit={submit}><p className="eyebrow">LIFEQUEST ADMIN</p><h1>관리자 로그인</h1><p className="muted">ADMIN 권한 계정으로 로그인하세요.</p><label>이메일<input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin@lifequest.kr" /></label><label>비밀번호<input type="password" required minLength={8} value={password} onChange={(e) => setPassword(e.target.value)} placeholder="8자 이상 입력" /></label>{error && <p className="formError">{error}</p>}<button className="primary full" disabled={busy}>{busy ? "확인 중…" : "관리자 콘솔 입장"}</button></form></section></main>;
}

function QuestModal({ quest, onClose, onSaved }: { quest: Quest | null; onClose: () => void; onSaved: () => void }) {
  const [draft, setDraft] = useState<Draft>(quest ? { ...quest } : emptyDraft);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const set = <K extends keyof Draft>(key: K, value: Draft[K]) => setDraft((current) => ({ ...current, [key]: value }));
  async function submit(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError("");
    try {
      const payload = { ...draft, placeName: draft.completionType === "LOCATION" ? draft.placeName : null, latitude: draft.completionType === "LOCATION" ? draft.latitude : null, longitude: draft.completionType === "LOCATION" ? draft.longitude : null, radiusM: draft.completionType === "LOCATION" ? draft.radiusM : null };
      await api(quest ? `/admin/quests/${quest.id}` : "/admin/quests", { method: quest ? "PATCH" : "POST", body: JSON.stringify(payload) });
      onSaved();
    } catch (reason) { setError(reason instanceof Error ? reason.message : "저장하지 못했습니다"); }
    finally { setBusy(false); }
  }
  async function deactivate() {
    if (!quest || !confirm("이 퀘스트를 비활성화할까요? 기존 기록은 보존됩니다.")) return;
    setBusy(true); try { await api(`/admin/quests/${quest.id}`, { method: "DELETE" }); onSaved(); } catch (reason) { setError(reason instanceof Error ? reason.message : "삭제하지 못했습니다"); } finally { setBusy(false); }
  }
  return <div className="modalBackdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}><section className="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><header><div><p className="eyebrow">QUEST EDITOR</p><h2 id="modal-title">{quest ? "퀘스트 수정" : "새 퀘스트 등록"}</h2></div><button className="close" onClick={onClose} aria-label="닫기">×</button></header><form onSubmit={submit}><div className="grid"><label className="span2">퀘스트 이름<input required maxLength={100} value={draft.title} onChange={(e) => set("title", e.target.value)} /></label><label className="span2">설명<textarea maxLength={500} rows={3} value={draft.description || ""} onChange={(e) => set("description", e.target.value)} /></label><Select label="등급" value={draft.grade} options={["NORMAL", "RARE", "EPIC", "LEGENDARY"]} onChange={(v) => set("grade", v as Draft["grade"])} /><Select label="주기" value={draft.cadence} options={["DAILY", "WEEKLY"]} onChange={(v) => set("cadence", v as Draft["cadence"])} /><Select label="완료 방식" value={draft.completionType} options={["SELF_REPORT", "LOCATION"]} onChange={(v) => set("completionType", v as Draft["completionType"])} /><label>EXP 보상<input type="number" min="1" required value={draft.expReward} onChange={(e) => set("expReward", Number(e.target.value))} /></label>{draft.completionType === "LOCATION" && <><label className="span2">장소명<input required value={draft.placeName || ""} onChange={(e) => set("placeName", e.target.value)} /></label><label>위도<input type="number" step="any" required value={draft.latitude ?? ""} onChange={(e) => set("latitude", Number(e.target.value))} /></label><label>경도<input type="number" step="any" required value={draft.longitude ?? ""} onChange={(e) => set("longitude", Number(e.target.value))} /></label><label>인증 반경(m)<input type="number" min="1" required value={draft.radiusM ?? ""} onChange={(e) => set("radiusM", Number(e.target.value))} /></label></>}</div>{error && <p className="formError">{error}</p>}<footer>{quest?.active && <button type="button" className="danger" onClick={() => void deactivate()}>비활성화</button>}<span /><button type="button" className="secondary" onClick={onClose}>취소</button><button className="primary" disabled={busy}>{busy ? "저장 중…" : "저장"}</button></footer></form></section></div>;
}

function Select({ label, value, options, onChange }: { label: string; value: string; options: string[]; onChange: (value: string) => void }) { return <label>{label}<select value={value} onChange={(e) => onChange(e.target.value)}>{options.map((option) => <option key={option}>{option}</option>)}</select></label>; }
function Stat({ label, value, tone }: { label: string; value: number; tone: string }) { return <article className={`stat ${tone}`}><small>{label}</small><strong>{value}</strong></article>; }
function Badge({ value }: { value: Quest["grade"] }) { return <span className={`badge ${value.toLowerCase()}`}>{value}</span>; }
