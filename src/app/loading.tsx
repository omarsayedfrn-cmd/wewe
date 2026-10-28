export default function Loading() {
  return (
    <div role="status" className="animate-pulse space-y-6">
      <span className="sr-only">جارٍ التحميل...</span>

      <div className="space-y-2">
        <div className="h-7 w-48 rounded-lg bg-[#1E1E1E]" />
        <div className="h-4 w-72 max-w-full rounded bg-[#1E1E1E]" />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, index) => (
          <div
            key={index}
            className="h-28 rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E]"
          />
        ))}
      </div>

      <div className="h-64 rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E]" />
    </div>
  );
}