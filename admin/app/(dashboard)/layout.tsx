import { Sidebar } from '@/components/sidebar'

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="min-h-screen">
      <Sidebar />
      <main className="lg:ml-60 p-6 pt-16 lg:pt-6">
        {children}
      </main>
    </div>
  )
}
