export function ErrorMessage({ message, className = '' }: { message: string | null; className?: string }) {
  if (!message) return null;

  return (
    <div className={`rounded-md bg-red-500/10 p-3 flex items-start space-x-2 ${className}`}>
      <svg
        className="h-5 w-5 text-red-500 shrink-0 mt-0.5"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        strokeWidth={2}
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
        />
      </svg>
      <p className="text-sm text-red-500">{message}</p>
    </div>
  );
}
