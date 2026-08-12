import fs from 'node:fs/promises';
import { Presentation, PresentationFile } from '@oai/artifact-tool';

const OUT='C:/workspace/LifeQuest/LifeQuest_Technical_Specification_Brand.pptx';
const RENDER='C:/workspace/LifeQuest/.codex-ppt/rendered';
const p=Presentation.create({slideSize:{width:1280,height:720}});
// LifeQuest design tokens: app/lib/shared/design/lq_tokens.dart
// Core identity = olive foliage, parchment surfaces, warm ink, quest gold.
const C={
  navy:'#55663D',      // primary olive
  ink:'#443B2A',       // text primary / warm ink
  muted:'#7A7060',     // secondary text
  cream:'#FEF8EE',     // main parchment surface
  white:'#FFFDF6',     // raised surface
  orange:'#C96A47',    // action accent / terracotta
  mint:'#8FA86A',      // growth green
  blue:'#9C87B5',      // location / system lavender
  line:'#D8CDB4',      // divider
  pale:'#FBF4E4',      // tinted parchment
  gold:'#E7B94F',
};
const FONT='Arial';
function box(s,x,y,w,h,fill=C.white,r='roundRect',line=C.line){return s.shapes.add({geometry:r,position:{left:x,top:y,width:w,height:h},fill,line:{style:'solid',fill:line,width:1},borderRadius:'rounded-xl'});}
function txt(s,text,x,y,w,h,size=18,color=C.ink,bold=false,align='left'){const t=s.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{style:'solid',fill:'none',width:0}});t.text=text;t.text.style={fontFamily:FONT,fontSize:size,color,bold,alignment:align,verticalAlignment:'middle'};return t;}
function header(s,n,title,kicker='TECHNICAL SPECIFICATION'){txt(s,kicker,64,34,500,24,12,C.orange,true);txt(s,title,64,64,1110,58,36,C.navy,true);txt(s,String(n).padStart(2,'0'),1160,42,56,30,14,C.muted,true,'right');}
function footer(s){txt(s,'LifeQuest | Technical Specification',64,682,420,18,10,C.muted,false);}
function base(n,title,k){const s=p.slides.add();s.background.fill=C.cream;header(s,n,title,k);footer(s);return s;}
function pill(s,label,x,y,w,color=C.navy){const b=box(s,x,y,w,34,color,'roundRect',color);txt(s,label,x,y,w,34,13,C.white,true,'center');return b;}
function flow(s,items,y=510){let x=70;const gap=16;const widths=items.map(v=>Math.max(110,Math.min(190,v.length*11+34)));items.forEach((it,i)=>{if(i){txt(s,'→',x-20,y,24,38,20,C.orange,true,'center');}box(s,x,y,widths[i],38,i===items.length-1?C.navy:C.white);txt(s,it,x+8,y,widths[i]-16,38,13,i===items.length-1?C.white:C.ink,true,'center');x+=widths[i]+gap;});}
function cards(n,title,items,sub=''){const s=base(n,title);if(sub)txt(s,sub,66,128,1120,48,18,C.muted);const cols=items.length<=4?2:3;const rows=Math.ceil(items.length/cols);const w=cols===2?548:356,h=rows===1?350:Math.min(190,(465-(rows-1)*18)/rows);items.forEach((it,i)=>{const col=i%cols,row=Math.floor(i/cols),x=66+col*(w+18),y=188+row*(h+18);box(s,x,y,w,h,i===0?C.pale:C.white);txt(s,it[0],x+24,y+18,w-48,36,22,C.navy,true);txt(s,it[1],x+24,y+58,w-48,h-72,16,C.ink);});return s;}
function screen(n,title,purpose,features,api,reason){const s=base(n,title,'USER FLOW · SCREEN SPEC');box(s,66,144,500,466,C.navy,'roundRect',C.navy);txt(s,'SCREENSHOT',66,280,500,42,28,C.white,true,'center');txt(s,'화면 이미지 삽입 영역',66,326,500,28,15,'#D8DFC5',false,'center');pill(s,'PURPOSE',602,144,110,C.orange);txt(s,purpose,602,184,590,64,18,C.ink,true);txt(s,'주요 기능',602,266,150,28,18,C.navy,true);txt(s,features.map(v=>'• '+v).join('\n'),602,300,590,126,16,C.ink);txt(s,'데이터 / API 처리',602,438,180,28,18,C.navy,true);txt(s,api,602,470,590,70,15,C.ink);txt(s,'구현 포인트',602,552,160,28,18,C.navy,true);txt(s,reason,602,584,590,58,15,C.muted);return s;}

// 1
{const s=p.slides.add();s.background.fill=C.navy;txt(s,'LIFE QUEST',70,120,760,92,58,C.white,true);txt(s,'일상을 퀘스트로, 경험치를 수집하는 현실 RPG',72,218,760,50,25,'#F3E9D0',false);pill(s,'PROJECT TECHNICAL SPECIFICATION',72,304,330,C.gold);txt(s,'Flutter App · Admin Web · Spring Boot · MySQL',72,360,650,32,18,'#D8DFC5');box(s,910,108,250,430,C.pale,'roundRect',C.pale);txt(s,'LV. 12',940,152,190,38,24,C.navy,true,'center');txt(s,'TODAY\n3 QUESTS',940,244,190,82,27,C.orange,true,'center');txt(s,'EXP 72%',940,376,190,34,18,C.navy,true,'center');txt(s,'프로젝트 기간  |  팀 프로젝트\n개발자 / 담당 역할',72,560,650,56,15,'#D8DFC5');txt(s,'LifeQuest | Technical Specification',72,674,420,18,10,'#BFC9A9');}
cards(2,'반복되는 일상에 “새로운 경험”을 설계한다', [['QUEST','일간·주간·지역·그룹 퀘스트로 행동을 시작합니다.'],['GROWTH','완료 기록은 EXP·레벨·보상으로 연결됩니다.'],['COLLECTION','업적·칭호·라이프덱스로 경험을 축적합니다.'],['SOCIAL','친구·그룹·랭킹이 지속 동기를 만듭니다.'],['LOCATION','GPS 기반 조건으로 현실 행동을 검증합니다.'],['AI','관심사와 조건을 입력해 새 퀘스트를 추천받습니다.']], '핵심은 할 일 관리가 아니라, 행동–보상–기록이 이어지는 성장 루프입니다.');
cards(3,'체크리스트의 한계를 경험 기반 루프로 전환', [['기존 문제','반복 체크와 일정 관리 중심이라 새로운 행동의 발견과 완료 후 성장감이 약합니다.'],['LifeQuest의 해법','새 장소·음식·지역 활동·그룹 도전을 퀘스트로 제안하고 결과를 성장 데이터로 남깁니다.'],['핵심 전환','일상 행동 → 퀘스트 → 경험치 → 성장 → 기록']], '사용자가 “해야 할 일”보다 “해보고 싶은 경험”을 발견하도록 설계했습니다.');
cards(4,'기능을 연결해야 하나의 서비스가 된다', [['01 직관적 경험','처음 접한 사용자도 퀘스트→수행→보상 흐름을 즉시 이해합니다.'],['02 기능 간 연결','완료가 EXP·레벨·업적·라이프덱스에 연쇄 반영됩니다.'],['03 실제 데이터 구조','앱 UI와 서버 도메인, 관계형 데이터가 동일한 규칙으로 움직입니다.'],['04 확장 가능한 구조','추천·지역·이벤트 기능을 도메인 단위로 확장할 수 있습니다.']]);
cards(5,'핵심 기능은 하나의 성장 경험을 분담한다', [['QUEST','일간 / 주간 / 지역 / 그룹'],['AI QUEST','장소·여행 조건 기반 추천'],['GROWTH','EXP / Level / Reward'],['ACHIEVEMENT','업적 / 대표 칭호'],['COLLECTION','라이프덱스 / 수집률'],['SOCIAL','친구 / 그룹 / 채팅 / 랭킹'],['LOCATION','GPS 권한 / 거리 검증']]);
{const s=base(6,'클라이언트는 REST API를 통해 하나의 백엔드 규칙을 공유한다');flow(s,['Flutter App','REST API','Spring Boot','JPA','MySQL'],255);flow(s,['Admin Web','REST API','Security / JWT','Domain Service'],365);txt(s,'확인된 스택',70,156,250,30,18,C.navy,true);txt(s,'Flutter · Riverpod · GoRouter   |   React · Vite   |   Java · Spring Boot · JPA · Flyway · MySQL',70,194,1100,36,18,C.ink);}
{const s=base(7,'사용자 중심 데이터 모델이 성장·소셜·지역 도메인을 연결한다');const groups=[['USER','User · SocialAccount · Character'],['QUEST','Quest · UserQuest · QuestProof'],['GROWTH','ExpLog · LevelReward · RewardGrant'],['COLLECTION','Achievement · Lifedex · Title'],['SOCIAL','Friendship · Group · GroupQuest · Chat'],['SYSTEM','Notification · Region · Location']];groups.forEach((g,i)=>{const x=70+(i%3)*382,y=170+Math.floor(i/3)*190;box(s,x,y,350,150,i===0?C.pale:C.white);txt(s,g[0],x+20,y+16,310,28,18,i===0?C.orange:C.navy,true);txt(s,g[1],x+20,y+54,310,72,16,C.ink);});txt(s,'실제 ERD 이미지 삽입 영역',70,568,1110,40,17,C.muted,true,'center');}
screen(8,'메인 화면','접속 직후 오늘의 행동과 성장 상태를 한눈에 확인합니다.',['프로필·레벨·EXP','오늘/진행 중 퀘스트','핵심 메뉴 이동'],'홈 API 응답을 Riverpod 상태로 보관하고 퀘스트·성장 데이터를 조합해 출력합니다.','첫 화면의 정보 우선순위를 행동 시작에 맞춥니다.');
screen(9,'일간 퀘스트','매일 부담 없이 실행할 수 있는 퀘스트를 제공합니다.',['목록·타이머·EXP','완료 상태','상세/수행 이동'],'GET quest assignments → 사용자별 UserQuest 상태와 만료 시간을 함께 반환합니다.','서버 시간이 일간 만료의 기준입니다.');
screen(10,'주간 퀘스트','일정 기간 누적되는 더 큰 목표와 보상을 제공합니다.',['주간 목록','진행률·조건','보상·남은 기간'],'주간 cadence와 진행 데이터를 조회해 남은 기간 및 상태를 계산합니다.','일간과 같은 모델을 쓰되 주기와 진행 표현을 분리합니다.');
screen(11,'AI 퀘스트 만들기','관심사와 조건으로 맞춤형 장소·여행 퀘스트를 추천합니다.',['유형 선택','조건 입력','추천 결과 확인','퀘스트 등록'],'입력 DTO → 추천 API → 결과 DTO → 선택 결과를 사용자 퀘스트로 등록합니다.','생성형 자유 입력이 아닌 검증 가능한 구조화 결과를 사용합니다.');
screen(12,'퀘스트 상세','선택한 퀘스트의 조건·보상·진행 상태를 확인합니다.',['설명·EXP','수행/위치 조건','현재 상태','도전 시작'],'questId로 상세 조회 후 사용자 할당 상태를 결합합니다.','수행 가능 여부를 서버 상태와 권한 조건으로 결정합니다.');
screen(13,'퀘스트 진행 / 인증','현실에서 수행한 행동을 위치 또는 인증 피드로 검증합니다.',['GPS 위치 확인','사진 인증','권한·반경 검증','완료 처리'],'권한 확인 → 좌표 취득 → 서버 거리 검증 → proof/complete API 호출.','민감한 위치 값은 완료 검증에 필요한 범위로 제한합니다.');
screen(14,'그룹 퀘스트','여러 사용자가 같은 목표를 함께 수행합니다.',['참여 인원','진행 상태','조건·보상','그룹 상세 이동'],'GroupQuest와 참여 테이블을 조회해 사용자별 참여/완료 상태를 분리합니다.','개인 완료와 그룹 전체 상태의 갱신 규칙을 분리합니다.');
screen(15,'그룹 만들기','사용자가 목적과 참여 조건을 정의해 그룹을 생성합니다.',['그룹명·소개','최대 인원','대표 이미지','생성'],'폼 검증 → POST groups → 생성자를 OWNER로 저장 → 상세로 이동합니다.','생성과 권한 부여를 하나의 트랜잭션으로 처리합니다.');
screen(16,'그룹 상세','그룹 정보·멤버·퀘스트·채팅을 한곳에서 관리합니다.',['멤버·권한','그룹 퀘스트','가입/탈퇴','채팅 이동'],'groupId 기준 상세/멤버/퀘스트 API를 병렬 조회하고 권한별 액션을 노출합니다.','OWNER·MEMBER 상태에 따라 변경 가능한 기능을 제한합니다.');
screen(17,'퀘스트 완료','완료 결과와 성장 데이터의 연쇄 변화를 즉시 보여줍니다.',['획득 EXP','레벨 변화','업적 진행','라이프덱스 등록'],'완료 API의 GrowthResult·Achievement·Collection 결과를 한 응답으로 표시합니다.','중복 완료 요청에도 보상이 한 번만 지급되도록 방어합니다.');
screen(18,'레벨업 / 레벨 보상','누적 EXP가 기준치를 넘으면 레벨과 보상을 갱신합니다.',['레벨 상승','누적 EXP 반영','보상 수령 상태'],'GrowthService가 EXP 로그를 저장하고 레벨 기준 및 보상 지급 여부를 계산합니다.','숫자 증가보다 다음 행동을 만드는 보상 피드백에 초점을 둡니다.');
screen(19,'업적','여러 행동의 누적 조건과 달성 진행률을 관리합니다.',['획득/미획득','달성 조건','진행률'],'AchievementService가 퀘스트·지역·그룹 이벤트 후 조건을 재평가합니다.','이벤트별 카운터가 동일 조건을 중복 반영하지 않게 합니다.');
screen(20,'칭호','획득한 칭호를 대표 프로필 표현으로 선택합니다.',['보유 칭호','획득 조건','대표 칭호 설정'],'사용자 칭호 목록 조회 → 대표 칭호 PATCH → 프로필 응답에 반영합니다.','대표 칭호는 보유 여부를 서버에서 검증합니다.');
screen(21,'라이프덱스','완료한 경험을 카테고리별 컬렉션으로 축적합니다.',['완료 경험 수집','카테고리·수집률','미완료 항목'],'Lifedex catalog와 UserLifedex를 결합해 잠금·완료·수집률을 반환합니다.','행동 로그가 아닌 의미 있는 경험 단위로 시각화합니다.');
screen(22,'친구','친구 관계와 요청 상태를 관리합니다.',['친구 검색·코드','요청/수락/삭제','친구 프로필'],'FriendRequest 상태 전이 후 양방향 Friendship을 생성하고 페이지 단위로 조회합니다.','중복 요청·자기 요청·차단 상태를 서버 규칙으로 방지합니다.');
screen(23,'친구 여정 / 비교','친구의 공개 성장 정보로 새로운 참여 동기를 만듭니다.',['Level·EXP','업적·라이프덱스','대표 칭호'],'공개 가능한 FriendProfileResponse만 반환해 비교 화면을 구성합니다.','경쟁보다 발견과 동기 부여를 중심으로 공개 범위를 제한합니다.');
screen(24,'랭킹','전체 또는 친구 범위에서 성장 순위를 확인합니다.',['전체/친구 랭킹','EXP·레벨','내 순위'],'RankingType에 따라 정렬·필터링한 페이지 응답을 반환합니다.','동점 기준과 페이지 순서를 서버에서 일관되게 유지합니다.');
screen(25,'알림','친구·그룹·성장 이벤트를 다음 행동으로 연결합니다.',['친구 요청','그룹 초대','완료·레벨업·업적','딥링크 이동'],'NotificationKind와 targetId를 저장하고 읽음 처리 후 관련 화면으로 라우팅합니다.','알림은 표시 문자열보다 이벤트 타입과 목적지를 중심으로 저장합니다.');
screen(26,'마이페이지','개인의 전체 성장 상태와 계정 진입점을 제공합니다.',['프로필·캐릭터','Level·EXP·칭호','업적·라이프덱스','친구·설정'],'프로필과 성장 스냅샷을 결합하고 각 세부 기능으로 이동합니다.','집계 값의 기준 시점을 응답 단위로 일치시킵니다.');
screen(27,'프로필 수정','여러 화면에 공유되는 사용자 표현 정보를 갱신합니다.',['닉네임·소개','캐릭터·액세서리','대표 칭호'],'PATCH profile 후 사용자 provider를 invalidate해 친구·그룹·랭킹에 재반영합니다.','서버 검증 후 클라이언트 캐시를 단일 경로로 갱신합니다.');
screen(28,'설정','알림·위치 권한과 계정 수명주기를 관리합니다.',['알림 설정','위치 권한','로그아웃','회원 탈퇴'],'OS 권한 상태와 서버 설정을 분리해 표시하고 토큰 삭제로 로그아웃합니다.','회원 탈퇴는 명시적 재확인과 서버 상태 변경을 거칩니다.');
cards(29,'운영자는 앱과 같은 API 규칙으로 서비스를 관리한다', [['서비스 현황','전체 사용자·퀘스트·수행 데이터를 집계합니다.'],['사용자 관리','계정 상태와 성장 정보를 조회합니다.'],['퀘스트 관리','카탈로그·주기·EXP·위치 조건을 관리합니다.'],['권한 분리','ADMIN 역할과 Spring Security 규칙으로 접근을 제한합니다.']]);
screen(30,'관리자 대시보드','운영에 필요한 핵심 현황과 최근 변화를 요약합니다.',['사용자·퀘스트 수','수행 현황','주요 통계','최근 활동'],'AdminDashboardService가 운영 집계를 DTO로 제공하고 React 화면이 시각화합니다.','운영 지표는 원천 데이터 기준과 집계 시점을 명시합니다.');
screen(31,'관리자 퀘스트 관리','운영 퀘스트의 카탈로그와 노출 조건을 관리합니다.',['등록·수정·삭제','주기·EXP','위치 조건'],'Admin Web → REST API → AdminQuestService → Quest repository → 앱 재조회.','관리자 변경과 사용자 할당 데이터를 구분해 기존 기록을 보존합니다.');
screen(32,'사용자 관리','가입 사용자와 계정 상태·성장 정보를 조회합니다.',['목록·검색','계정 상태','Level·EXP','상세 조회'],'페이지·검색 조건을 AdminUserController로 전달하고 관리 권한을 검증합니다.','개인 데이터는 운영 목적에 필요한 범위만 노출합니다.');
{const s=base(33,'로그인부터 화면 출력까지 계층별 책임을 분리한다');flow(s,['로그인','JWT 인증','Controller','Service','Repository / JPA','MySQL'],210);flow(s,['퀘스트 API','DTO 응답','Repository','Riverpod 상태','Flutter UI'],350);txt(s,'원칙',70,490,120,28,18,C.orange,true);txt(s,'화면은 상태를 표현하고, 도메인 규칙은 서비스에, 영속성 규칙은 저장소 계층에 둡니다.',70,530,1100,44,22,C.navy,true);}
{const s=base(34,'퀘스트 완료는 하나의 트랜잭션으로 성장 데이터를 일관되게 갱신한다');flow(s,['사용자·퀘스트 확인','조건 검증','UserQuest 완료','EXP 기록','레벨 계산'],192);flow(s,['보상 지급','업적 평가','라이프덱스 갱신','결과 DTO 반환'],330);txt(s,'트랜잭션 경계',70,472,220,28,18,C.orange,true);txt(s,'완료 상태와 보상·성장 데이터가 일부만 반영되지 않도록 서버 서비스 계층에서 처리 순서를 통제합니다.',70,514,1100,56,21,C.navy,true);}
{const s=base(35,'JWT와 역할 기반 인가가 사용자별 데이터 접근을 통제한다');flow(s,['Login','자격 검증','JWT 발급','Token 저장','API 전달','Security 인증'],230);flow(s,['사용자 식별','권한 확인','도메인 접근','응답'],370);txt(s,'보안 경계',70,510,150,28,18,C.orange,true);txt(s,'클라이언트가 전달한 userId를 신뢰하지 않고 인증 컨텍스트의 사용자와 리소스 소유권을 검증합니다.',70,548,1100,50,20,C.navy,true);}
cards(36,'개발 중 문제는 데이터 흐름의 경계를 명확히 하며 해결했다', [['Problem 01','퀘스트 완료가 EXP·레벨·업적·라이프덱스에 동시에 영향을 주어 일관성 유지가 어려웠습니다.'],['Solution 01','완료 서비스에 트랜잭션 경계를 두고 처리 순서와 중복 방지 규칙을 정의했습니다.'],['Problem 02','앱과 관리자 웹이 같은 데이터를 서로 다른 방식으로 변경할 수 있었습니다.'],['Solution 02','Spring Boot REST API를 단일 백엔드 진입점으로 두고 역할별 인가를 적용했습니다.'],['Problem 03','위치 권한·좌표 오차·반경 조건 때문에 예외 상황이 다양했습니다.'],['Solution 03','클라이언트 권한 확인과 서버 거리 검증을 분리해 신뢰 경계를 명확히 했습니다.']]);
cards(37,'배운 것은 기술 목록보다 연결 규칙의 중요성이다', [['기능 간 연결','한 번의 완료가 여러 도메인에 미치는 영향을 추적하며 서비스 경계를 설계했습니다.'],['클라이언트–서버 흐름','Flutter 행동이 REST API와 DB를 거쳐 다시 상태로 반영되는 전 과정을 다뤘습니다.'],['협업의 기준','공통 DTO·API 규칙·마이그레이션이 병렬 개발의 안정성을 좌우했습니다.']]);
cards(38,'LifeQuest는 CRUD를 서비스 흐름으로 연결한 프로젝트다', [['성장 데이터의 연쇄','Quest 완료 이후 EXP·레벨·보상·업적·수집이 일관되게 갱신됩니다.'],['사용자와 운영의 연결','Flutter 앱과 React 관리자 웹이 하나의 Spring Boot API를 공유합니다.'],['다음 성장','화면 단위 구현을 넘어 전체 구조와 데이터 흐름을 이해하는 개발자로 확장했습니다.']]);
{const s=base(39,'현실의 행동을 성장 데이터로 연결하는 하나의 아키텍처');const items=[['Flutter App',100,220,C.blue],['Admin Web',100,390,C.mint],['Spring Boot · REST API',470,305,C.orange],['MySQL · Flyway',850,305,C.navy],['AI · GPS',850,170,C.mint],['Quest · Growth · Social',850,445,C.blue]];items.forEach(([t,x,y,c])=>{box(s,x,y,260,76,c,'roundRect',c);txt(s,t,x+12,y,236,76,18,C.white,true,'center');});txt(s,'→',380,305,70,76,30,C.orange,true,'center');txt(s,'→',750,305,70,76,30,C.orange,true,'center');txt(s,'LifeQuest  |  행동을 퀘스트로 만들고, 기록을 성장으로 연결한다.',100,590,1080,42,24,C.navy,true,'center');}

console.log('slides',p.slides.items.length);
const pptx=await PresentationFile.exportPptx(p);console.log('exported');await pptx.save(OUT);
console.log(OUT);
