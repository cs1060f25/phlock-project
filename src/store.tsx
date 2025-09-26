import React, { createContext, useContext, useMemo, useState } from 'react'
import { initialCrate, initialLeaderboard, initialActivity, initialInbox, type CrateItem, type PlugScore, type Share, type Activity, type InboxItem } from './data'

type Store = {
  crate: CrateItem[]
  leaderboard: PlugScore[]
  activity: Activity[]
  inbox: InboxItem[]
  addToCrate: (share: Share) => void
  forwardShare: (trackId: string, toUser: string) => void
  addToCrateFromInbox: (trackId: string, fromUser: string) => void
  removeFromInbox: (trackId: string) => void
}

const Ctx = createContext<Store | null>(null)

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [crate, setCrate] = useState(initialCrate)
  const [leaderboard, setLeaderboard] = useState(initialLeaderboard)
  const [activity] = useState(initialActivity)
  const [inbox, setInbox] = useState(initialInbox)

  const addToCrate = (share: Share) => {
    setCrate((c) => [{ trackId: share.trackId, fromUser: share.fromUser, addedAt: new Date().toISOString() }, ...c])
    setLeaderboard((lb) => {
      const i = lb.findIndex((x) => x.user === share.fromUser)
      if (i >= 0) {
        const copy = lb.slice()
        copy[i] = { ...copy[i], score: copy[i].score + 10 }
        return copy.sort((a, b) => b.score - a.score)
      }
      return [{ user: share.fromUser, score: 10 }, ...lb].sort((a, b) => b.score - a.score)
    })
  }

  const forwardShare = (trackId: string, toUser: string) => {
    console.info(`Forwarded track ${trackId} to ${toUser}`)
    setLeaderboard((lb) => {
      const i = lb.findIndex((x) => x.user === 'sarah')
      if (i >= 0) {
        const copy = lb.slice()
        copy[i] = { ...copy[i], score: copy[i].score + 5 }
        return copy.sort((a, b) => b.score - a.score)
      }
      return lb
    })
  }

  const addToCrateFromInbox = (trackId: string, fromUser: string) => {
    setCrate((c) => [{ trackId, fromUser, addedAt: new Date().toISOString() }, ...c])
    setInbox((i) => i.filter(item => item.trackId !== trackId))
    setLeaderboard((lb) => {
      const i = lb.findIndex((x) => x.user === fromUser)
      if (i >= 0) {
        const copy = lb.slice()
        copy[i] = { ...copy[i], score: copy[i].score + 10 } // save = +10
        return copy.sort((a, b) => b.score - a.score)
      }
      return [{ user: fromUser, score: 10 }, ...lb].sort((a, b) => b.score - a.score)
    })
    console.info(`Added track ${trackId} to crate from ${fromUser}`)
  }

  const removeFromInbox = (trackId: string) => {
    setInbox((i) => i.filter(item => item.trackId !== trackId))
    console.info(`Removed track ${trackId} from inbox`)
  }

  const value = useMemo(() => ({ crate, leaderboard, activity, inbox, addToCrate, forwardShare, addToCrateFromInbox, removeFromInbox }), [crate, leaderboard, activity, inbox])
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export const useStore = () => {
  const v = useContext(Ctx)
  if (!v) throw new Error('Store missing')
  return v
}
