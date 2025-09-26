import { StoreProvider } from "./store"
import React from 'react'
import ReactDOM from 'react-dom/client'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import { Landing, HomeMenuFan, HomeMenuArtist, Search, Receive, Crate, Share, Leaderboard, ArtistDashboard, ArtistProfile } from './pages'
import './index.css'

const router = createBrowserRouter([
  { path: '/', element: <Landing /> },
  { path: '/home-menu-fan', element: <HomeMenuFan /> },
  { path: '/home-menu-artist', element: <HomeMenuArtist /> },
  { path: '/search', element: <Search /> },
  { path: '/r/:id', element: <Receive /> },
  { path: '/crate', element: <Crate /> },
  { path: '/share', element: <Share /> },
  { path: '/leaderboard/:artistId', element: <Leaderboard /> },
  { path: '/artist/:artistId/dashboard', element: <ArtistDashboard /> },
  { path: '/artist-profile', element: <ArtistProfile /> },
])

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <StoreProvider><RouterProvider router={router} /></StoreProvider>
  </React.StrictMode>,
)
