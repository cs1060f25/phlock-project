export default function WaveDivider({ width = '100%', opacity = 0.4 }: { width?: string | number; opacity?: number }) {
  return (
    <svg viewBox="0 0 400 24" width={width} height="24" style={{ opacity, display: 'block', margin: '0 auto' }}>
      <path
        d="M0,12 C25,4 25,20 50,12 C75,4 75,20 100,12 C125,4 125,20 150,12 C175,4 175,20 200,12 C225,4 225,20 250,12 C275,4 275,20 300,12 C325,4 325,20 350,12 C375,4 375,20 400,12"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  )
}


